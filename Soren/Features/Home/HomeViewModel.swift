import Foundation

typealias CurrentMonthSnapshotCalculation = @Sendable (
    _ today: Date,
    _ calendar: Calendar,
    _ reportingCurrencyCode: String,
    _ exchangeRateSnapshot: ExchangeRateSnapshot?
) async throws -> CurrentMonthSubscriptionPlanSnapshot

typealias OverviewInsightCalculation = @Sendable (
    _ today: Date,
    _ calendar: Calendar,
    _ reportingCurrencyCode: String,
    _ exchangeRateSnapshot: ExchangeRateSnapshot?
) async throws -> OverviewInsight?

// MARK: - Home View Model

/// Produces one coherent production Overview snapshot from the current-month
/// plan, selected insight, and nearest canonical scheduled charges.
@MainActor @Observable
final class HomeViewModel {
    private(set) var screenState: HomeScreenState
    private(set) var normalizationError: BillingCycle.ValidationError?

    var monthLabel: String { screenState.monthLabel }
    var monthlyPlan: MonthlyPlanHeroPresentation { screenState.monthlyPlan }
    var monthSchedule: MonthSchedulePresentation? { screenState.monthSchedule }
    var statusCounts: SubscriptionStatusCounts? { screenState.statusCounts }
    var overviewInsight: OverviewInsightPresentation? { screenState.overviewInsight }
    var upcoming: UpcomingChargesPresentation { screenState.upcoming }
    var isLoaded: Bool { screenState.isLoaded }
    var hasError: Bool { screenState.hasError }

    private let getUpcomingCharges: GetUpcomingCharges
    private let preferences: UserPreferencesRepository
    private let loadExchangeRateSnapshot: @Sendable () async throws -> ExchangeRateSnapshot
    private let calculateCurrentMonth: CurrentMonthSnapshotCalculation
    private let calculateOverviewInsight: OverviewInsightCalculation
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    private let timeZone: @Sendable () -> TimeZone

    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var loadRevision = 0
    private var isLoading = false

    init<Provider: ExchangeRateProvider>(
        getUpcomingCharges: GetUpcomingCharges,
        preferences: UserPreferencesRepository,
        exchangeRateProvider: Provider,
        calculateCurrentMonth: @escaping CurrentMonthSnapshotCalculation,
        calculateOverviewInsight: @escaping OverviewInsightCalculation = { _, _, _, _ in nil },
        now: @escaping @Sendable () -> Date = { .now },
        calendar: Calendar,
        timeZone: (@Sendable () -> TimeZone)? = nil
    ) {
        self.getUpcomingCharges = getUpcomingCharges
        self.preferences = preferences
        self.loadExchangeRateSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
        self.calculateCurrentMonth = calculateCurrentMonth
        self.calculateOverviewInsight = calculateOverviewInsight
        self.now = now
        self.calendar = BillingCivilDay.calendar
        self.timeZone = timeZone ?? { calendar.timeZone }

        let initialDay = try? BillingCivilDay.civilDate(containing: now(), in: self.timeZone())
        let initialDate = initialDay.flatMap { try? BillingCivilDay.canonicalDate(for: $0) } ?? now()
        self.screenState = Self.loadingState(today: initialDate, calendar: self.calendar)
    }

    // MARK: - Load

    func load(forceReload: Bool = false) async {
        guard forceReload || (!screenState.isLoaded && !isLoading) else { return }

        loadRevision += 1
        let revision = loadRevision
        isLoading = true

        let reportingCurrencyCode = preferences.load().defaultCurrencyCode

        do {
            let day = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
            let today = try BillingCivilDay.canonicalDate(for: day)
            let startOfToday = today
            let visibleUpcoming = try getUpcomingCharges.execute(
                from: startOfToday,
                calendar: calendar
            )

            let localResult = await calculateDomainState(
                today: today,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: exchangeRateSnapshot
            )

            guard !Task.isCancelled, revision == loadRevision else { return }
            publish(
                result: localResult,
                upcomingOccurrences: visibleUpcoming,
                today: today
            )

            if shouldRefreshExchangeRates(result: localResult) {
                await refreshWithExchangeRates(
                    revision: revision,
                    today: today,
                    reportingCurrencyCode: reportingCurrencyCode,
                    upcomingOccurrences: visibleUpcoming
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
                monthSchedule: screenState.monthSchedule,
                statusCounts: screenState.statusCounts,
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
        async let currentMonthResult = optionalResult {
            try await self.calculateCurrentMonth(
                today,
                self.calendar,
                reportingCurrencyCode,
                snapshot
            )
        }
        async let insightResult = insightCalculationResult {
            try await self.calculateOverviewInsight(
                today,
                self.calendar,
                reportingCurrencyCode,
                snapshot
            )
        }

        let insight = await insightResult
        return await DomainState(currentMonth: currentMonthResult,
            insight: insight.value, normalizationError: insight.error)
    }

    private func insightCalculationResult(
        _ operation: @escaping @Sendable () async throws -> OverviewInsight?
    ) async -> (value: OverviewInsight?, error: BillingCycle.ValidationError?) {
        do { return (try await operation(), nil) }
        catch let error as BillingCycle.ValidationError { return (nil, error) }
        catch { return (nil, nil) }
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
        upcomingOccurrences: [UpcomingScheduledCharge]
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
                upcomingOccurrences: upcomingOccurrences,
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
        upcomingOccurrences: [UpcomingScheduledCharge],
        today: Date
    ) {
        normalizationError = result.normalizationError
        screenState = HomeScreenState(
            monthLabel: Self.monthLabel(for: today, calendar: calendar),
            monthlyPlan: Self.monthlyPlanPresentation(
                result.currentMonth?.plan
            ),
            monthSchedule: result.currentMonth.flatMap {
                Self.monthSchedulePresentation($0, today: today, calendar: calendar)
            },
            statusCounts: result.currentMonth?.statusCounts,
            overviewInsight: result.normalizationError != nil
                ? OverviewInsightPresentation(kind: .annualScale,
                    primary: String(localized: "normalization.unavailable"),
                    supporting: String(localized: "при текущем наборе подписок"))
                : result.insight.map {
                OverviewInsightPresentation.make(from: $0, today: today, calendar: calendar)
            },
            upcoming: upcomingPresentation(
                occurrences: upcomingOccurrences
            ),
            isLoaded: true,
            hasError: false
        )
    }

    // MARK: - FX Decision

    private func shouldRefreshExchangeRates(result: DomainState) -> Bool {
        if result.currentMonth?.plan == nil { return true }

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
            monthSchedule: nil,
            statusCounts: nil,
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
        occurrences: [UpcomingScheduledCharge]
    ) -> UpcomingChargesPresentation {
        let rows = occurrences.map { occurrence in
            let item = occurrence.item
            let providerName = item.providerName.isEmpty ? item.title : item.providerName
            let amount = OverviewMoneyFormatter.string(occurrence.money)
            let date = Self.formattedDate(occurrence.date, calendar: calendar)

            return UpcomingChargePresentation(
                item: item,
                scheduledDate: occurrence.date,
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

    private static func monthSchedulePresentation(
        _ snapshot: CurrentMonthSubscriptionPlanSnapshot,
        today: Date,
        calendar: Calendar
    ) -> MonthSchedulePresentation? {
        guard let days = calendar.range(of: .day, in: .month, for: today) else { return nil }
        return MonthSchedulePresentation(
            year: calendar.component(.year, from: today),
            month: calendar.component(.month, from: today),
            daysInMonth: days.count,
            todayDay: calendar.component(.day, from: today),
            occurrences: snapshot.scheduledCharges.map {
                MonthSchedulePresentation.Occurrence(
                    itemID: $0.itemID,
                    day: calendar.component(.day, from: $0.date)
                )
            }
        )
    }
}

private extension HomeViewModel {
    struct DomainState: Sendable {
        let currentMonth: CurrentMonthSubscriptionPlanSnapshot?
        let insight: OverviewInsight?
        let normalizationError: BillingCycle.ValidationError?
    }
}
