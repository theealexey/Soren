import Foundation

enum CurrentMonthSubscriptionPlanUseCaseError: Error, Equatable, Sendable {
    case invalidCalendarArithmetic
}

/// Projects every proven recurring charge occurrence in the current calendar
/// month and aggregates it into one complete reporting-currency plan.
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
        let fetchedItems = try await repository.fetchAll()
        let bounds = try DateBounds(today: today, calendar: calendar)
        let items = deduplicatedItems(fetchedItems)
        let projector = RecurringScheduleProjector()

        var plannedProjections: [RecurringSpendProjection] = []

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
            guard projection.monetaryCompleteness == .complete else {
                return nil
            }

            for event in projection.events {
                guard case let .scheduledCharge(_, date, money) = event else {
                    continue
                }
                plannedProjections.append(
                    RecurringSpendProjection(
                        date: date,
                        amount: money.amount,
                        currencyCode: money.currencyCode
                    )
                )
            }
        }

        plannedProjections.sort(by: stableProjectionOrder)
        let remainingProjections = plannedProjections.filter {
            $0.date >= bounds.startOfToday
        }

        guard let plannedTotal = completeTotal(
            for: plannedProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            range: bounds.monthRange
        ),
        let remainingTotal = completeTotal(
            for: remainingProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            range: bounds.remainingRange
        ) else {
            return nil
        }

        return MonthlySubscriptionPlan(
            plannedTotal: plannedTotal,
            chargeCount: plannedProjections.count,
            remainingTotal: remainingTotal,
            remainingChargeCount: remainingProjections.count
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
