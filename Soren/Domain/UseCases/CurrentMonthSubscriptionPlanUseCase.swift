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
        let eligibleItems = eligibleItems(
            from: deduplicatedItems(fetchedItems),
            today: bounds.startOfToday,
            calendar: calendar
        )

        var plannedProjections: [RecurringSpendProjection] = []

        for item in eligibleItems {
            guard let terms = provenChargeTerms(for: item, calendar: calendar) else {
                // An otherwise eligible item with unproven terms makes a complete
                // month plan impossible. Never publish a plausible partial total.
                return nil
            }

            guard let occurrenceDates = try occurrenceDates(
                for: terms,
                in: bounds.monthRange,
                calendar: calendar
            ) else {
                return nil
            }

            plannedProjections.append(contentsOf: occurrenceDates.map { date in
                RecurringSpendProjection(
                    date: date,
                    amount: terms.money.amount,
                    currencyCode: terms.money.currencyCode
                )
            })
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

// MARK: - Eligibility and Charge Terms

private extension CurrentMonthSubscriptionPlanUseCase {
    struct ChargeTerms {
        let money: Money
        let billingCycle: BillingCycle
        let scheduleAnchor: Date
        let effectiveStartDate: Date
        let effectiveEndDate: Date?
    }

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

    func eligibleItems(
        from items: [RecurringItem],
        today: Date,
        calendar: Calendar
    ) -> [RecurringItem] {
        items.filter { item in
            guard item.status.countsInTotals, item.archivedAt == nil else { return false }
            guard !item.autoRenew else { return true }
            guard let endDate = item.endDate else { return false }
            return calendar.startOfDay(for: endDate) >= today
        }
    }

    func provenChargeTerms(
        for item: RecurringItem,
        calendar: Calendar
    ) -> ChargeTerms? {
        guard item.amount > 0,
              isValid(item.billingCycle),
              let money = try? Money(amount: item.amount, currencyCode: item.currencyCode)
        else {
            return nil
        }

        let startDate = calendar.startOfDay(for: item.startDate)
        let scheduleAnchor = calendar.startOfDay(for: item.nextChargeDate)
        let endDate = item.autoRenew
            ? nil
            : item.endDate.map { calendar.startOfDay(for: $0) }

        if let endDate {
            guard startDate <= endDate, scheduleAnchor <= endDate else {
                return nil
            }
        }

        if item.status == .trial {
            guard item.autoRenew,
                  let trialEndDate = item.trialEndDate,
                  item.nextChargeDate >= trialEndDate,
                  calendar.isDate(item.nextChargeDate, inSameDayAs: trialEndDate)
            else {
                return nil
            }

            return ChargeTerms(
                money: money,
                billingCycle: item.billingCycle,
                scheduleAnchor: scheduleAnchor,
                effectiveStartDate: max(startDate, calendar.startOfDay(for: trialEndDate)),
                effectiveEndDate: nil
            )
        }

        return ChargeTerms(
            money: money,
            billingCycle: item.billingCycle,
            scheduleAnchor: scheduleAnchor,
            effectiveStartDate: startDate,
            effectiveEndDate: endDate
        )
    }

    func isValid(_ billingCycle: BillingCycle) -> Bool {
        if case let .custom(days) = billingCycle {
            return days > 0
        }
        return true
    }
}

// MARK: - Calendar-Month Occurrence Projection

private extension CurrentMonthSubscriptionPlanUseCase {
    static var maximumProjectionSteps: Int { 100_000 }

    func occurrenceDates(
        for terms: ChargeTerms,
        in monthRange: Range<Date>,
        calendar: Calendar
    ) throws -> [Date]? {
        // `nextChargeDate` is the authoritative schedule datum. Forward stepping
        // reuses `BillingCycle.nextDate`; inverse calendar stepping recovers only
        // the earlier scheduled portion of this same current-month plan.
        var dates = Set<Date>()
        let anchor = terms.scheduleAnchor

        if anchor >= monthRange.lowerBound {
            var candidate = anchor
            var steps = 0

            while candidate >= monthRange.lowerBound {
                guard steps < Self.maximumProjectionSteps else { return nil }
                if monthRange.contains(candidate), isWithinLifecycle(candidate, terms: terms) {
                    dates.insert(candidate)
                }

                guard let previous = previousDate(
                    before: candidate,
                    billingCycle: terms.billingCycle,
                    calendar: calendar
                ), previous < candidate else {
                    throw CurrentMonthSubscriptionPlanUseCaseError.invalidCalendarArithmetic
                }
                candidate = previous
                steps += 1
            }
        }

        var candidate = anchor
        var steps = 0

        if candidate >= monthRange.lowerBound {
            candidate = terms.billingCycle.nextDate(after: candidate, calendar: calendar)
            guard candidate > anchor else {
                throw CurrentMonthSubscriptionPlanUseCaseError.invalidCalendarArithmetic
            }
            steps += 1
        }

        while candidate < monthRange.upperBound {
            guard steps < Self.maximumProjectionSteps else { return nil }
            if monthRange.contains(candidate), isWithinLifecycle(candidate, terms: terms) {
                dates.insert(candidate)
            }

            let next = terms.billingCycle.nextDate(after: candidate, calendar: calendar)
            guard next > candidate else {
                throw CurrentMonthSubscriptionPlanUseCaseError.invalidCalendarArithmetic
            }
            candidate = next
            steps += 1
        }

        return dates.sorted()
    }

    func previousDate(
        before date: Date,
        billingCycle: BillingCycle,
        calendar: Calendar
    ) -> Date? {
        switch billingCycle {
        case .weekly:
            return calendar.date(byAdding: .day, value: -7, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: -1, to: date)
        case .quarterly:
            return calendar.date(byAdding: .month, value: -3, to: date)
        case .semiannual:
            return calendar.date(byAdding: .month, value: -6, to: date)
        case .annual:
            return calendar.date(byAdding: .year, value: -1, to: date)
        case let .custom(days):
            guard days > 0 else { return nil }
            return calendar.date(byAdding: .day, value: -days, to: date)
        }
    }

    func isWithinLifecycle(_ date: Date, terms: ChargeTerms) -> Bool {
        guard date >= terms.effectiveStartDate else { return false }
        guard let endDate = terms.effectiveEndDate else { return true }
        return date <= endDate
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
