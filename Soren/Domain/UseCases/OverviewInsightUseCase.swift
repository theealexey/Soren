import Foundation

enum OverviewInsightUseCaseError: Error, Equatable, Sendable {
    case invalidCalendarArithmetic
}

/// Deterministically selects one Overview insight from the full recurring-item set.
///
/// Repository access crosses its existing `@MainActor` boundary once. Selection,
/// date arithmetic, and money aggregation remain actor-neutral Domain work.
struct OverviewInsightUseCase<Repository>: Sendable
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
    ) async throws -> OverviewInsight? {
        let fetchedItems = try await repository.fetchAll()
        let bounds = try DateBounds(today: today, calendar: calendar)
        let eligibleItems = eligibleItems(
            from: deduplicatedItems(fetchedItems),
            today: bounds.startOfToday,
            calendar: calendar
        )

        guard !eligibleItems.isEmpty else { return nil }

        if let trialAttention = trialEndingAttention(
            in: eligibleItems,
            today: today,
            endExclusive: bounds.trialAttentionEnd,
            calendar: calendar
        ) {
            return .attention(.trialEnding(trialAttention))
        }

        let upcomingEvents = try nearestChargeEvents(
            for: eligibleItems,
            from: bounds.startOfToday,
            before: bounds.thirtyDayEnd,
            calendar: calendar
        )
        let sevenDayEvents = upcomingEvents.filter { $0.date < bounds.sevenDayEnd }

        if let sameDayAttention = try sameDayAttention(
            in: sevenDayEvents,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            calendar: calendar
        ) {
            return .attention(.sameDayRenewals(sameDayAttention))
        }

        if let denseWeek = try denseWeek(
            in: upcomingEvents,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            calendar: calendar
        ) {
            return .denseWeek(denseWeek)
        }

        return try annualScale(
            for: eligibleItems,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot,
            range: bounds.startOfToday..<bounds.oneDayEnd,
            calendar: calendar
        )
    }
}

// MARK: - Date Bounds

private extension OverviewInsightUseCase {
    struct DateBounds {
        let startOfToday: Date
        let oneDayEnd: Date
        let trialAttentionEnd: Date
        let sevenDayEnd: Date
        let thirtyDayEnd: Date

        init(today: Date, calendar: Calendar) throws {
            let startOfToday = calendar.startOfDay(for: today)
            guard let oneDayEnd = calendar.date(byAdding: .day, value: 1, to: startOfToday),
                  let trialAttentionEnd = calendar.date(byAdding: .day, value: 4, to: startOfToday),
                  let sevenDayEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday),
                  let thirtyDayEnd = calendar.date(byAdding: .day, value: 30, to: startOfToday)
            else {
                throw OverviewInsightUseCaseError.invalidCalendarArithmetic
            }

            self.startOfToday = startOfToday
            self.oneDayEnd = oneDayEnd
            self.trialAttentionEnd = trialAttentionEnd
            self.sevenDayEnd = sevenDayEnd
            self.thirtyDayEnd = thirtyDayEnd
        }
    }
}

// MARK: - Eligibility

private extension OverviewInsightUseCase {
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
}

// MARK: - Trial Attention

private extension OverviewInsightUseCase {
    func trialEndingAttention(
        in items: [RecurringItem],
        today: Date,
        endExclusive: Date,
        calendar: Calendar
    ) -> OverviewInsight.TrialEnding? {
        let candidates = items.compactMap { item -> (RecurringItem, Date)? in
            guard item.status == .trial, let trialEndDate = item.trialEndDate else { return nil }
            let trialEndDay = calendar.startOfDay(for: trialEndDate)
            guard trialEndDate >= today, trialEndDay < endExclusive else { return nil }
            return (item, trialEndDate)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.id.uuidString < rhs.0.id.uuidString
        }

        guard let (item, trialEndDate) = candidates.first else { return nil }
        return OverviewInsight.TrialEnding(
            itemID: item.id,
            itemTitle: item.title,
            trialEndDate: trialEndDate,
            renewalTerms: provenRenewalTerms(for: item, calendar: calendar)
        )
    }

    func provenRenewalTerms(
        for item: RecurringItem,
        calendar: Calendar
    ) -> OverviewInsight.RenewalTerms? {
        guard item.status == .trial,
              item.autoRenew,
              item.amount > 0,
              let trialEndDate = item.trialEndDate,
              item.nextChargeDate >= trialEndDate,
              calendar.isDate(item.nextChargeDate, inSameDayAs: trialEndDate),
              isValid(item.billingCycle),
              let amount = try? Money(amount: item.amount, currencyCode: item.currencyCode)
        else {
            return nil
        }

        return OverviewInsight.RenewalTerms(
            amount: amount,
            billingCycle: item.billingCycle
        )
    }
}

// MARK: - Charge Events

private struct OverviewInsightChargeEvent: Sendable {
    let item: RecurringItem
    let date: Date
}

private extension OverviewInsightUseCase {
    func nearestChargeEvents(
        for items: [RecurringItem],
        from startDate: Date,
        before endDate: Date,
        calendar: Calendar
    ) throws -> [OverviewInsightChargeEvent] {
        let today = try BillingCivilDay.civilDate(fromCanonicalDate: startDate)
        return try items.compactMap { item -> OverviewInsightChargeEvent? in
            let effectiveDate = try item.effectiveNextChargeDate(relativeTo: today)
            let chargeDay = calendar.startOfDay(for: effectiveDate)
            guard chargeDay >= startDate, chargeDay < endDate else { return nil }

            if !item.autoRenew {
                guard let endDate = item.endDate,
                      chargeDay <= calendar.startOfDay(for: endDate)
                else {
                    return nil
                }
            }

            return OverviewInsightChargeEvent(item: item, date: chargeDay)
        }
        .sorted(by: stableEventOrder)
    }

    func stableEventOrder(
        _ lhs: OverviewInsightChargeEvent,
        _ rhs: OverviewInsightChargeEvent
    ) -> Bool {
        if lhs.date != rhs.date { return lhs.date < rhs.date }
        return lhs.item.id.uuidString < rhs.item.id.uuidString
    }
}

// MARK: - Same-Day Attention

private extension OverviewInsightUseCase {
    func sameDayAttention(
        in events: [OverviewInsightChargeEvent],
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?,
        calendar: Calendar
    ) throws -> OverviewInsight.SameDayRenewals? {
        let qualifyingGroups = Dictionary(grouping: events, by: \.date)
            .filter { $0.value.count >= 3 }
            .sorted { $0.key < $1.key }

        guard let (chargeDate, matchingEvents) = qualifyingGroups.first else { return nil }
        return OverviewInsight.SameDayRenewals(
            chargeDate: chargeDate,
            itemIDs: sortedIDs(in: matchingEvents),
            total: try completeTotal(
                for: matchingEvents,
                reportingCurrencyCode: reportingCurrencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot,
                calendar: calendar
            )
        )
    }
}

// MARK: - Dense Week

private struct OverviewDenseWeekCandidate {
    let order: OverviewDenseWeekCandidateOrder
    let events: [OverviewInsightChargeEvent]
}

/// Internal ordering key kept explicit so every product tie-break remains testable.
struct OverviewDenseWeekCandidateOrder: Equatable, Sendable {
    let chargeCount: Int
    let windowStart: Date
    let actualSpan: TimeInterval
    let itemIDs: [UUID]

    func isPreferred(to other: Self) -> Bool {
        if chargeCount != other.chargeCount { return chargeCount > other.chargeCount }
        if windowStart != other.windowStart { return windowStart < other.windowStart }
        if actualSpan != other.actualSpan { return actualSpan < other.actualSpan }
        return itemIDs.map(\.uuidString).lexicographicallyPrecedes(
            other.itemIDs.map(\.uuidString)
        )
    }
}

private extension OverviewInsightUseCase {
    func denseWeek(
        in events: [OverviewInsightChargeEvent],
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?,
        calendar: Calendar
    ) throws -> OverviewInsight.DenseWeek? {
        let candidateStartDates = Array(Set(events.map(\.date))).sorted()
        let candidates = try candidateStartDates.compactMap { startDate -> OverviewDenseWeekCandidate? in
            guard let endDate = calendar.date(byAdding: .day, value: 7, to: startDate) else {
                throw OverviewInsightUseCaseError.invalidCalendarArithmetic
            }
            let matchingEvents = events.filter { $0.date >= startDate && $0.date < endDate }
            guard matchingEvents.count >= 3,
                  let firstDate = matchingEvents.first?.date,
                  let lastDate = matchingEvents.last?.date
            else {
                return nil
            }

            let itemIDs = sortedIDs(in: matchingEvents)
            return OverviewDenseWeekCandidate(
                order: OverviewDenseWeekCandidateOrder(
                    chargeCount: matchingEvents.count,
                    windowStart: startDate,
                    actualSpan: lastDate.timeIntervalSince(firstDate),
                    itemIDs: itemIDs
                ),
                events: matchingEvents
            )
        }

        let selectedCandidate = candidates.reduce(
            nil as OverviewDenseWeekCandidate?,
            { current, candidate in
                guard let current else { return candidate }
                return candidate.order.isPreferred(to: current.order) ? candidate : current
            }
        )
        guard let selected = selectedCandidate,
              let firstDate = selected.events.first?.date,
              let lastDate = selected.events.last?.date
        else {
            return nil
        }

        return OverviewInsight.DenseWeek(
            firstChargeDate: firstDate,
            lastChargeDate: lastDate,
            itemIDs: selected.order.itemIDs,
            total: try completeTotal(
                for: selected.events,
                reportingCurrencyCode: reportingCurrencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot,
                calendar: calendar
            )
        )
    }
}

// MARK: - Annual Scale

private extension OverviewInsightUseCase {
    func annualScale(
        for items: [RecurringItem],
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?,
        range: Range<Date>,
        calendar: Calendar
    ) throws -> OverviewInsight? {
        let projections = try items.compactMap { item -> RecurringSpendProjection? in
            let money: Money
            let billingCycle: BillingCycle

            if item.status == .trial {
                guard let terms = provenRenewalTerms(for: item, calendar: calendar) else {
                    return nil
                }
                money = terms.amount
                billingCycle = terms.billingCycle
            } else {
                guard item.amount >= 0,
                      let validatedMoney = try? Money(
                          amount: item.amount,
                          currencyCode: item.currencyCode
                      )
                else {
                    return nil
                }
                money = validatedMoney
                billingCycle = item.billingCycle
            }

            return RecurringSpendProjection(
                date: range.lowerBound,
                amount: try billingCycle.annualEquivalent(for: money.amount),
                currencyCode: money.currencyCode
            )
        }

        guard projections.count == items.count else { return nil }

        let result = aggregateSpend.execute(
            projections: projections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: exchangeRateSnapshot,
            range: range
        )
        guard case let .complete(total, _) = result, total.amount > 0 else { return nil }
        return .annualScale(total)
    }

    func isValid(_ billingCycle: BillingCycle) -> Bool {
        if case let .custom(days) = billingCycle {
            return days > 0
        }
        return true
    }
}

// MARK: - Complete Money Aggregation

private extension OverviewInsightUseCase {
    func completeTotal(
        for events: [OverviewInsightChargeEvent],
        reportingCurrencyCode: String,
        exchangeRateSnapshot: ExchangeRateSnapshot?,
        calendar: Calendar
    ) throws -> Money? {
        guard let firstDate = events.first?.date,
              let lastDate = events.last?.date,
              events.allSatisfy({ $0.item.amount >= 0 }),
              let rangeEnd = calendar.date(byAdding: .day, value: 1, to: lastDate)
        else {
            if events.isEmpty || events.contains(where: { $0.item.amount < 0 }) {
                return nil
            }
            throw OverviewInsightUseCaseError.invalidCalendarArithmetic
        }

        let projections = events.map {
            RecurringSpendProjection(
                date: $0.date,
                amount: $0.item.amount,
                currencyCode: $0.item.currencyCode
            )
        }
        let result = aggregateSpend.execute(
            projections: projections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: exchangeRateSnapshot,
            range: firstDate..<rangeEnd
        )
        guard case let .complete(total, _) = result else { return nil }
        return total
    }

    func sortedIDs(in events: [OverviewInsightChargeEvent]) -> [UUID] {
        events.map(\.item.id).sorted { $0.uuidString < $1.uuidString }
    }
}
