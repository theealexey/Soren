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
        exchangeRateProvider: Provider,
        calculateMonthlyPlan: @escaping MonthlySubscriptionPlanCalculation = { _, _, _, _ in nil },
        calculateOverviewInsight: @escaping OverviewInsightCalculation = { _, _, _, _ in nil },
        now: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar = .current
    ) {
        self.getUpcomingCharges = getUpcomingCharges
        self.preferences = preferences
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
                today: today
            )

            if shouldRefreshExchangeRates(result: localResult) {
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
                today: today
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
        today: Date
    ) {
        screenState = HomeScreenState(
            monthLabel: Self.monthLabel(for: today, calendar: calendar),
            monthlyPlan: Self.monthlyPlanPresentation(
                result.monthlyPlan
            ),
            overviewInsight: result.insight.map {
                OverviewInsightPresentation.make(from: $0, today: today, calendar: calendar)
            },
            upcoming: upcomingPresentation(
                items: upcomingItems,
                today: today
            ),
            isLoaded: true,
            hasError: false
        )
    }

    // MARK: - FX Decision

    private func shouldRefreshExchangeRates(result: DomainState) -> Bool {
        if result.monthlyPlan == nil { return true }

        switch result.insight {
        case let .denseWeek(denseWeek) where denseWeek.total == nil:
            return true
        case let .attention(.sameDayRenewals(sameDay)) where sameDay.total == nil:
            return true
        default:
            break
        }

        return false
    }

    // MARK: - Monthly Plan Presentation

    private static func loadingState(today: Date, calendar: Calendar) -> HomeScreenState {
        HomeScreenState(
            monthLabel: monthLabel(for: today, calendar: calendar),
            monthlyPlan: monthlyPlanPresentation(nil),
            overviewInsight: nil,
            upcoming: UpcomingChargesPresentation(rows: []),
            isLoaded: false,
            hasError: false
        )
    }

    private static func monthlyPlanPresentation(
        _ plan: MonthlySubscriptionPlan?
    ) -> MonthlyPlanHeroPresentation {
        let title = String(localized: "overview.monthlyPlan.scheduled")

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

        if plan.chargeCount == 0 {
            let empty = String(localized: "overview.monthlyPlan.empty")
            return MonthlyPlanHeroPresentation(
                title: title,
                primary: empty,
                primaryStyle: .statement,
                leadingSupport: "",
                trailingSupportLabel: nil,
                trailingSupportValue: nil,
                accessibilityLabel: [title, empty].joined(separator: ". ")
            )
        }

        let amount = OverviewMoneyFormatter.string(plan.plannedTotal)
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
        today: Date
    ) -> UpcomingChargesPresentation {
        let startOfToday = calendar.startOfDay(for: today)
        let rows = items.map { item in
            let providerName = item.providerName.isEmpty ? item.title : item.providerName
            let chargeDate = item.effectiveNextChargeDate(
                relativeTo: startOfToday,
                calendar: calendar
            )
            let amount = OverviewMoneyFormatter.string(
                amount: item.amount,
                currencyCode: item.currencyCode
            )
            let date = Self.formattedDate(chargeDate, calendar: calendar)

            return UpcomingChargePresentation(
                item: item,
                providerName: providerName,
                amount: amount,
                chargeDate: date,
                accessibilityLabel: [providerName, date, amount].joined(separator: ", ")
            )
        }

        return UpcomingChargesPresentation(rows: rows)
    }

    // MARK: - Formatting

    private static func monthLabel(for date: Date, calendar: Calendar) -> String {
        let month = monthName(for: date, calendar: calendar)
            .capitalized(with: PresentationLocale.current)
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
