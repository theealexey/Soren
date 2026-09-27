import Foundation

enum CurrentMonthSubscriptionPlanUseCaseError: Error, Equatable, Sendable {
    case invalidCalendarArithmetic
}

/// Projects proven recurring charge occurrences in the current calendar month.
/// The reporting-currency plan is present only when monetary truth is complete.
///
/// Repository access crosses its existing `@MainActor` boundary once. Date
/// projection and monetary aggregation remain actor-neutral Domain work.
struct CurrentMonthSubscriptionPlanUseCase<Repository>: Sendable
where Repository: RecurringItemRepository, Repository: Sendable {
    private let repository: Repository
    private let aggregateSpend: AggregateRecurringSpendUseCase

    init(
        repository: Repository,
        aggregateSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase()
    ) {
        self.repository = repository
        self.aggregateSpend = aggregateSpend
    }

    func execute(
        today: Date,
        calendar: Calendar,
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?
    ) async throws -> MonthlySubscriptionPlan? {
        try await executeSnapshot(
            today: today,
            calendar: calendar,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot
        ).plan
    }

    func executeSnapshot(
        today: Date,
        calendar: Calendar,
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?
    ) async throws -> CurrentMonthSubscriptionPlanSnapshot {
        let fetchedItems = try await repository.fetchAll()
        let bounds = try DateBounds(today: today, calendar: calendar)
        let items = deduplicatedItems(fetchedItems)
        let projector = RecurringScheduleProjector()

        var plannedProjections: [RecurringSpendProjection] = []
        var scheduledCharges: [ScheduledChargeOccurrence] = []
        var isMonetarilyComplete = true

        for item in items {
            let projection: RecurringScheduleProjection
            do {
                projection = try projector.project(
                    item,
                    in: bounds.monthRange,
                    asOf: bounds.startOfToday,
                    calendar: calendar
                )
            } catch RecurringScheduleProjectionError.invalidCalendarArithmetic {
                throw CurrentMonthSubscriptionPlanUseCaseError.invalidCalendarArithmetic
            }
            if projection.monetaryCompleteness != .complete {
                isMonetarilyComplete = false
            }

            for event in projection.events {
                guard case let .scheduledCharge(itemID, date, money) = event else {
                    continue
                }
                plannedProjections.append(
                    RecurringSpendProjection(
                        date: date,
                        amount: money.amount,
                        currencyCode: money.currencyCode
                    )
                )
                scheduledCharges.append(
                    ScheduledChargeOccurrence(itemID: itemID, date: date)
                )
            }
        }

        plannedProjections.sort(by: stableProjectionOrder)
        scheduledCharges.sort(by: stableOccurrenceOrder)
        let remainingProjections = plannedProjections.filter {
            $0.date >= bounds.startOfToday
        }

        let plannedTotal = isMonetarilyComplete ? completeTotal(
            for: plannedProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            range: bounds.monthRange
        ) : nil
        let remainingTotal = isMonetarilyComplete ? completeTotal(
            for: remainingProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            range: bounds.remainingRange
        ) : nil

        let plan: MonthlySubscriptionPlan?
        if let plannedTotal, let remainingTotal {
            plan = MonthlySubscriptionPlan(
                plannedTotal: plannedTotal,
                chargeCount: plannedProjections.count,
                remainingTotal: remainingTotal,
                remainingChargeCount: remainingProjections.count
            )
        } else {
            plan = nil
        }

        return CurrentMonthSubscriptionPlanSnapshot(
            plan: plan,
            scheduledCharges: scheduledCharges,
            statusCounts: statusCounts(
                for: items,
                today: bounds.startOfToday,
                calendar: calendar
            )
        )
    }
}

// MARK: - Date Bounds

private extension CurrentMonthSubscriptionPlanUseCase {
    struct DateBounds {
        let startOfToday: Date
        let startOfMonth: Date
        let startOfNextMonth: Date

        var monthRange: Range<Date> {
            startOfMonth..<startOfNextMonth
        }

        var remainingRange: Range<Date> {
            startOfToday..<startOfNextMonth
        }

        init(today: Date, calendar: Calendar) throws {
            let startOfToday = calendar.startOfDay(for: today)
            let monthComponents = calendar.dateComponents([.era, .year, .month], from: startOfToday)

            guard let startOfMonth = calendar.date(from: monthComponents),
                  let startOfNextMonth = calendar.date(
                      byAdding: .month,
                      value: 1,
                      to: startOfMonth
                  ),
                  startOfMonth <= startOfToday,
                  startOfToday < startOfNextMonth
            else {
                throw CurrentMonthSubscriptionPlanUseCaseError.invalidCalendarArithmetic
            }

            self.startOfToday = startOfToday
            self.startOfMonth = startOfMonth
            self.startOfNextMonth = startOfNextMonth
        }
    }
}

// MARK: - Item Identity

private extension CurrentMonthSubscriptionPlanUseCase {
    func deduplicatedItems(_ items: [RecurringItem]) -> [RecurringItem] {
        let ordered = items.sorted(by: stableItemOrder)
        var seenIDs = Set<UUID>()
        return ordered.filter { seenIDs.insert($0.id).inserted }
    }

    func stableItemOrder(_ lhs: RecurringItem, _ rhs: RecurringItem) -> Bool {
        let lhsID = lhs.id.uuidString
        let rhsID = rhs.id.uuidString
        if lhsID != rhsID { return lhsID < rhsID }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        if lhs.nextChargeDate != rhs.nextChargeDate { return lhs.nextChargeDate < rhs.nextChargeDate }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        if lhs.currencyCode != rhs.currencyCode { return lhs.currencyCode < rhs.currencyCode }
        return lhs.amount < rhs.amount
    }

    func stableOccurrenceOrder(
        _ lhs: ScheduledChargeOccurrence,
        _ rhs: ScheduledChargeOccurrence
    ) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        return lhs.itemID.uuidString < rhs.itemID.uuidString
    }
}

// MARK: - Current Status Counts

private extension CurrentMonthSubscriptionPlanUseCase {
    func statusCounts(
        for items: [RecurringItem],
        today: Date,
        calendar: Calendar
    ) -> SubscriptionStatusCounts {
        var active = 0
        var trial = 0
        var paused = 0

        for item in items {
            guard item.archivedAt == nil else { continue }
            if let endDate = item.endDate,
               calendar.compare(endDate, to: today, toGranularity: .day) == .orderedAscending {
                continue
            }

            switch item.status {
            case .active, .dueSoon, .dueToday, .overdue, .failed:
                active += 1
            case .trial:
                trial += 1
            case .paused:
                paused += 1
            case .cancelled, .archived:
                break
            }
        }

        return SubscriptionStatusCounts(active: active, trial: trial, paused: paused)
    }
}

// MARK: - Complete Money Aggregation

private extension CurrentMonthSubscriptionPlanUseCase {
    func completeTotal(
        for projections: [RecurringSpendProjection],
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?,
        range: Range<Date>
    ) -> Money? {
        let result = aggregateSpend.execute(
            projections: projections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: exchangeRateSnapshot,
            range: range
        )
        guard case let .complete(total, _) = result else { return nil }
        return total
    }

    func stableProjectionOrder(
        _ lhs: RecurringSpendProjection,
        _ rhs: RecurringSpendProjection
    ) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        if lhs.currencyCode != rhs.currencyCode { return lhs.currencyCode < rhs.currencyCode }
        return lhs.amount < rhs.amount
    }
}
