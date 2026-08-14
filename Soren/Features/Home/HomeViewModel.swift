import Foundation

typealias MonthlySubscriptionPlanCalculation = @Sendable (
    _ today: Date,
    _ calendar: Calendar,
    _ reportingCurrencyCode: String,
    _ exchangeRateSnapshot: ExchangeRateSnapshot?
) async throws -> MonthlySubscriptionPlan?

typealias OverviewInsightCalculation = @Sendable (
    _ today: Date,
    _ calendar: Calendar,
    _ reportingCurrencyCode: String,
    _ exchangeRateSnapshot: ExchangeRateSnapshot?
) async throws -> OverviewInsight?

// MARK: - Home View Model

/// Produces one coherent production Overview snapshot from the current-month
/// plan, selected insight, and nearest recurring charges.
@MainActor @Observable
final class HomeViewModel {
    private(set) var screenState: HomeScreenState

    var monthLabel: String { screenState.monthLabel }
    var monthlyPlan: MonthlyPlanHeroPresentation { screenState.monthlyPlan }
    var overviewInsight: OverviewInsightPresentation? { screenState.overviewInsight }
    var upcoming: UpcomingChargesPresentation { screenState.upcoming }
    var isLoaded: Bool { screenState.isLoaded }
    var hasError: Bool { screenState.hasError }

    private let getUpcomingCharges: GetUpcomingCharges
    private let preferences: UserPreferencesRepository
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let loadExchangeRateSnapshot: @Sendable () async throws -> ExchangeRateSnapshot
    private let calculateMonthlyPlan: MonthlySubscriptionPlanCalculation
    private let calculateOverviewInsight: OverviewInsightCalculation
    private let now: @Sendable () -> Date
    private let calendar: Calendar

    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var loadRevision = 0
    private var isLoading = false

    init<Provider: ExchangeRateProvider>(
        getUpcomingCharges: GetUpcomingCharges,
        preferences: UserPreferencesRepository,
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        exchangeRateProvider: Provider,
        calculateMonthlyPlan: @escaping MonthlySubscriptionPlanCalculation = { _, _, _, _ in nil },
        calculateOverviewInsight: @escaping OverviewInsightCalculation = { _, _, _, _ in nil },
        now: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        self.getUpcomingCharges = getUpcomingCharges
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.loadExchangeRateSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
        self.calculateMonthlyPlan = calculateMonthlyPlan
        self.calculateOverviewInsight = calculateOverviewInsight
        self.now = now
        self.calendar = calendar

        let initialDate = now()
        self.screenState = Self.loadingState(today: initialDate, calendar: calendar)
    }

    // MARK: - Load

    func load(forceReload: Bool = false) async {
        guard forceReload || (!screenState.isLoaded && !isLoading) else { return }

        loadRevision += 1
        let revision = loadRevision
        isLoading = true

        let today = now()
        let startOfToday = calendar.startOfDay(for: today)
        let reportingCurrencyCode = preferences.load().defaultCurrencyCode

        do {
            let upcomingItems = try getUpcomingCharges
                .execute(days: 30, from: startOfToday)
                .filter { Self.isEligibleUpcoming($0, today: startOfToday, calendar: calendar) }
            let visibleUpcoming = Array(upcomingItems.prefix(3))

            let localResult = await calculateDomainState(
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: exchangeRateSnapshot
            )

            guard !Task.isCancelled, revision == loadRevision else { return }
            publish(
                result: localResult,
                upcomingItems: visibleUpcoming,
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: exchangeRateSnapshot
            )

            if shouldRefreshExchangeRates(
                result: localResult,
                upcomingItems: visibleUpcoming,
                today: startOfToday,
                reportingCurrencyCode: reportingCurrencyCode
            ) {
                await refreshWithExchangeRates(
                    revision: revision,
                    today: today,
                    reportingCurrencyCode: reportingCurrencyCode,
                    upcomingItems: visibleUpcoming
                )
            }

            guard revision == loadRevision else { return }
            isLoading = false
        } catch is CancellationError {
            guard revision == loadRevision else { return }
            isLoading = false
        } catch {
            guard revision == loadRevision else { return }
            isLoading = false
            screenState = HomeScreenState(
                monthLabel: screenState.monthLabel,
                monthlyPlan: screenState.monthlyPlan,
                overviewInsight: screenState.overviewInsight,
                upcoming: screenState.upcoming,
                isLoaded: screenState.isLoaded,
                hasError: true
            )
        }
    }

    private func calculateDomainState(
        today: Date,
        reportingCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) async -> DomainState {
        async let monthlyPlanResult = optionalResult {
            try await self.calculateMonthlyPlan(
                today,
                self.calendar,
                reportingCurrencyCode,
                snapshot
            )
        }
        async let insightResult = optionalResult {
            try await self.calculateOverviewInsight(
                today,
                self.calendar,
                reportingCurrencyCode,
                snapshot
            )
        }

        return await DomainState(
            monthlyPlan: monthlyPlanResult,
            insight: insightResult
        )
    }

    private func optionalResult<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value?
    ) async -> Value? {
        do {
            return try await operation()
        } catch {
            return nil
        }
    }

    private func refreshWithExchangeRates(
        revision: Int,
        today: Date,
        reportingCurrencyCode: String,
        upcomingItems: [RecurringItem]
    ) async {
        do {
            let snapshot = try await loadExchangeRateSnapshot()
            guard !Task.isCancelled, revision == loadRevision else { return }

            let refreshedResult = await calculateDomainState(
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot
            )
            guard !Task.isCancelled, revision == loadRevision else { return }

            exchangeRateSnapshot = snapshot
            publish(
                result: refreshedResult,
                upcomingItems: upcomingItems,
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot
            )
        } catch is CancellationError {
            return
        } catch {
            // The local snapshot is already truthful: unavailable values stay unavailable.
        }
    }

    private func publish(
        result: DomainState,
        upcomingItems: [RecurringItem],
        today: Date,
        reportingCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) {
        screenState = HomeScreenState(
            monthLabel: Self.monthLabel(for: today, calendar: calendar),
            monthlyPlan: Self.monthlyPlanPresentation(
                result.monthlyPlan,
                today: today,
                calendar: calendar,
                reportingCurrencyCode: reportingCurrencyCode
            ),
            overviewInsight: result.insight.map {
                OverviewInsightPresentation.make(from: $0, today: today, calendar: calendar)
            },
            upcoming: upcomingPresentation(
                items: upcomingItems,
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot
            ),
            isLoaded: true,
            hasError: false
        )
    }

    // MARK: - FX Decision

    private func shouldRefreshExchangeRates(
        result: DomainState,
        upcomingItems: [RecurringItem],
        today: Date,
        reportingCurrencyCode: String
    ) -> Bool {
        if result.monthlyPlan == nil { return true }

        switch result.insight {
        case let .denseWeek(denseWeek) where denseWeek.total == nil:
            return true
        case let .attention(.sameDayRenewals(sameDay)) where sameDay.total == nil:
            return true
        default:
            break
        }

        guard let end = calendar.date(byAdding: .day, value: 30, to: today) else {
            return false
        }
        return aggregateRecurringSpend.requiresExchangeRates(
            projections: projections(from: upcomingItems, relativeTo: today),
            reportingCurrencyCode: reportingCurrencyCode,
            range: today..<end
        )
    }

    // MARK: - Monthly Plan Presentation

    private static func loadingState(today: Date, calendar: Calendar) -> HomeScreenState {
        HomeScreenState(
            monthLabel: monthLabel(for: today, calendar: calendar),
            monthlyPlan: monthlyPlanPresentation(
                nil,
                today: today,
                calendar: calendar,
                reportingCurrencyCode: UserPreferences.default.defaultCurrencyCode
            ),
            overviewInsight: nil,
            upcoming: UpcomingChargesPresentation(
                rows: [],
                aggregateMetadata: nil,
                emptyMessage: String(localized: "Нет списаний в ближайшие 30 дней")
            ),
            isLoaded: false,
            hasError: false
        )
    }

    private static func monthlyPlanPresentation(
        _ plan: MonthlySubscriptionPlan?,
        today: Date,
        calendar: Calendar,
        reportingCurrencyCode: String
    ) -> MonthlyPlanHeroPresentation {
        let month = monthName(for: today, calendar: calendar)
        let title = String(localized: "План на \(month)")

        guard let plan else {
            let unavailable = String(localized: "План недоступен")
            let support = String(localized: "Полная сумма не рассчитана")
            return MonthlyPlanHeroPresentation(
                title: title,
                primary: unavailable,
                primaryStyle: .statement,
                leadingSupport: support,
                trailingSupportLabel: nil,
                trailingSupportValue: nil,
                accessibilityLabel: [title, unavailable, support].joined(separator: ". ")
            )
        }

        let amount = OverviewMoneyFormatter.string(plan.plannedTotal)
        if plan.chargeCount == 0 {
            let empty = String(localized: "Нет запланированных списаний")
            return MonthlyPlanHeroPresentation(
                title: title,
                primary: amount,
                primaryStyle: .financialValue,
                leadingSupport: empty,
                trailingSupportLabel: nil,
                trailingSupportValue: nil,
                accessibilityLabel: [title, amount, empty].joined(separator: ". ")
            )
        }

        let count = String(localized: "\(plan.chargeCount) списаний")
        let isEntirePlanRemaining = plan.remainingTotal == plan.plannedTotal
            && plan.remainingChargeCount == plan.chargeCount

        guard !isEntirePlanRemaining else {
            return MonthlyPlanHeroPresentation(
                title: title,
                primary: amount,
                primaryStyle: .financialValue,
                leadingSupport: count,
                trailingSupportLabel: nil,
                trailingSupportValue: nil,
                accessibilityLabel: [title, amount, count].joined(separator: ". ")
            )
        }

        let remainingAmount = OverviewMoneyFormatter.string(plan.remainingTotal)
        let remainingCount = String(localized: "\(plan.remainingChargeCount) списаний")
        let remainingLabel = String(localized: "Осталось")

        return MonthlyPlanHeroPresentation(
            title: title,
            primary: amount,
            primaryStyle: .financialValue,
            leadingSupport: count,
            trailingSupportLabel: remainingLabel,
            trailingSupportValue: remainingAmount,
            accessibilityLabel: [
                title,
                amount,
                count,
                "\(remainingLabel): \(remainingAmount), \(remainingCount)",
            ].joined(separator: ". ")
        )
    }

    // MARK: - Upcoming Presentation

    private func upcomingPresentation(
        items: [RecurringItem],
        today: Date,
        reportingCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> UpcomingChargesPresentation {
        let startOfToday = calendar.startOfDay(for: today)
        let rows = items.map { item in
            let providerName = item.providerName.isEmpty ? item.title : item.providerName
            let chargeDate = item.effectiveNextChargeDate(
                relativeTo: startOfToday,
                calendar: calendar
            )
            let planOrCycle = Self.planOrCycleLabel(for: item, providerName: providerName)
            let amount = OverviewMoneyFormatter.string(
                amount: item.amount,
                currencyCode: item.currencyCode
            )
            let date = Self.formattedDate(chargeDate, calendar: calendar)

            return UpcomingChargePresentation(
                item: item,
                providerName: providerName,
                planOrCycle: planOrCycle,
                amount: amount,
                chargeDate: date,
                artworkScale: Self.artworkScale(for: item.providerID),
                accessibilityLabel: [providerName, planOrCycle, amount, date].joined(separator: ", ")
            )
        }

        let aggregate = upcomingAggregate(
            items: items,
            today: startOfToday,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot
        )
        let count = String(localized: "\(rows.count) списаний")
        let metadata: String?
        if rows.isEmpty {
            metadata = nil
        } else {
            metadata = aggregate.map {
                "\(count) · \(OverviewMoneyFormatter.string($0))"
            } ?? count
        }

        return UpcomingChargesPresentation(
            rows: rows,
            aggregateMetadata: metadata,
            emptyMessage: String(localized: "Нет списаний в ближайшие 30 дней")
        )
    }

    private func upcomingAggregate(
        items: [RecurringItem],
        today: Date,
        reportingCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?
    ) -> Money? {
        guard let end = calendar.date(byAdding: .day, value: 30, to: today) else { return nil }
        let result = aggregateRecurringSpend.execute(
            projections: projections(from: items, relativeTo: today),
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: today..<end
        )
        guard case let .complete(total, _) = result else { return nil }
        return total
    }

    private func projections(
        from items: [RecurringItem],
        relativeTo today: Date
    ) -> [RecurringSpendProjection] {
        items.map { item in
            RecurringSpendProjection(
                date: calendar.startOfDay(
                    for: item.effectiveNextChargeDate(relativeTo: today, calendar: calendar)
                ),
                amount: item.amount,
                currencyCode: item.currencyCode
            )
        }
    }

    // MARK: - Formatting

    private static func monthLabel(for date: Date, calendar: Calendar) -> String {
        let month = monthName(for: date, calendar: calendar)
            .uppercased(with: PresentationLocale.current)
        let year = calendar.component(.year, from: date)
        return "\(month) \(year)"
    }

    private static func monthName(for date: Date, calendar: Calendar) -> String {
        let formatter = PresentationLocale.dateFormatter(
            template: "LLLL",
            calendar: calendar
        )
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date).lowercased(with: PresentationLocale.current)
    }

    private static func formattedDate(_ date: Date, calendar: Calendar) -> String {
        let formatter = PresentationLocale.dateFormatter(
            template: "dMMMM",
            calendar: calendar
        )
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static func planOrCycleLabel(
        for item: RecurringItem,
        providerName: String
    ) -> String {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.range(
            of: providerName,
            options: [.anchored, .caseInsensitive]
        ) != nil {
            let suffix = trimmedTitle.dropFirst(providerName.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty { return suffix }
        }

        switch item.billingCycle {
        case .weekly:
            return String(localized: "Еженедельно")
        case .monthly:
            return String(localized: "Ежемесячно")
        case .quarterly:
            return String(localized: "Раз в 3 месяца")
        case .semiannual:
            return String(localized: "Раз в полгода")
        case .annual:
            return String(localized: "Ежегодно")
        case let .custom(days):
            return String(localized: "Каждые \(days) дн.")
        }
    }

    private static func artworkScale(for providerID: String?) -> Double {
        switch providerID {
        case "spotify": 0.75
        case "youtube_premium": 0.975
        case "icloud": 1.10
        default: 1
        }
    }

    private static func isEligibleUpcoming(
        _ item: RecurringItem,
        today: Date,
        calendar: Calendar
    ) -> Bool {
        guard item.status.countsInTotals, item.archivedAt == nil else { return false }
        guard !item.autoRenew else { return true }
        guard let endDate = item.endDate else { return false }
        return calendar.startOfDay(for: endDate) >= today
    }
}

private extension HomeViewModel {
    struct DomainState: Sendable {
        let monthlyPlan: MonthlySubscriptionPlan?
        let insight: OverviewInsight?
    }
}
