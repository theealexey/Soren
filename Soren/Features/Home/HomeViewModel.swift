import Foundation

private enum HomeLoadError: Error {
    case invalidDateRange
}

// MARK: - Home View Model

/// Drives the Billing Landscape Home screen.
/// Receives explicit use-case dependencies — no RepositoryContainer or AppContainer access.
/// All output is value types (String, Decimal, structs). No SwiftUI types returned.
@MainActor @Observable
final class HomeViewModel {

    // MARK: - Output

    private(set) var monthLabel: String = ""
    private(set) var forecastLabel: String = ""
    private(set) var forecastAggregation: RecurringSpendAggregationResult?
    private(set) var landscapePoints: [BillingLandscapePoint] = []
    private(set) var callout: NextPaymentCalloutState = .nextPayment(
        countdown: "", name: "", amountFormatted: "", additionalCount: 0
    )
    private(set) var calloutNavigationItem: RecurringItem?
    private(set) var insights: [InsightRowModel] = []
    private(set) var upcomingCharges: [RecurringItem] = []
    private(set) var selection: BillingLandscapeSelection? = nil
    private(set) var isLoaded = false
    private(set) var error: Error? = nil

    var hasError: Bool { error != nil }

    /// Full snapshot — useful for unit tests and SwiftUI previews.
    var screenState: HomeScreenState {
        HomeScreenState(
            monthLabel: monthLabel,
            forecastLabel: forecastLabel,
            forecastAggregation: forecastAggregation,
            landscapePoints: landscapePoints,
            callout: callout,
            calloutNavigationItem: calloutNavigationItem,
            insights: insights,
            upcomingCharges: upcomingCharges,
            isLoaded: isLoaded,
            hasError: hasError
        )
    }

    // MARK: - Dependencies

    private let getUpcomingCharges: GetUpcomingCharges
    private let getActiveTrials: GetActiveTrials
    private let preferences: UserPreferencesRepository
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let loadExchangeRateSnapshot: @Sendable () async throws -> ExchangeRateSnapshot

    // MARK: - Cache

    /// Populated on load. Enables instant selectDate() without a repository hit.
    private var cachedItemsByDay: [Date: [RecurringItem]] = [:]
    private var cachedUpcoming: [RecurringItem] = []
    /// Subset of the fetched upcoming items that is eligible for financial presentation.
    /// Keep the raw collection separately so non-financial UI can retain its established contract.
    private var cachedFinancialUpcoming: [RecurringItem] = []
    private var cachedTrials: [RecurringItem] = []
    private var cachedWindowStart: Date?
    private var cachedWindowEnd: Date?
    private var reportingCurrencyCode = UserPreferences.default.defaultCurrencyCode
    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var aggregationRevision = 0

    private let calendar = Calendar.current

    // MARK: - Init

    init<Provider: ExchangeRateProvider>(
        getUpcomingCharges: GetUpcomingCharges,
        getActiveTrials: GetActiveTrials,
        preferences: UserPreferencesRepository,
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        exchangeRateProvider: Provider
    ) {
        self.getUpcomingCharges = getUpcomingCharges
        self.getActiveTrials = getActiveTrials
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.loadExchangeRateSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        error = nil
        selection = nil
        calloutNavigationItem = nil
        aggregationRevision += 1

        do {
            let now = Date.now
            // Window starts at the beginning of today so charges scheduled at 00:00
            // (or any earlier time today) are included. Exact Date.now would exclude them.
            let windowStart = calendar.startOfDay(for: now)
            let windowDays = 30
            guard let windowEnd = calendar.date(
                byAdding: .day,
                value: windowDays,
                to: windowStart
            ) else {
                throw HomeLoadError.invalidDateRange
            }

            // Expired finite subscriptions (autoRenew=false, endDate past) are excluded from
            // the active forecast so they don't inflate upcoming totals or landscape bars.
            let upcoming = try getUpcomingCharges.execute(days: windowDays, from: windowStart)
                .filter { !$0.isExpired }
            let financialUpcoming = upcoming.filter(\.status.countsInTotals)
            let trials   = try getActiveTrials.execute()
            reportingCurrencyCode = preferences.load().defaultCurrencyCode

            // Group by effective charge date so rolled-forward items land in the correct bucket.
            let grouped: [Date: [RecurringItem]] = Dictionary(
                grouping: financialUpcoming,
                by: {
                    calendar.startOfDay(
                        for: $0.effectiveNextChargeDate(relativeTo: windowStart, calendar: calendar)
                    )
                }
            )
            cachedItemsByDay = grouped
            cachedUpcoming = upcoming
            cachedFinancialUpcoming = financialUpcoming
            cachedTrials = trials
            cachedWindowStart = windowStart
            cachedWindowEnd = windowEnd

            rebuildPresentation(snapshot: exchangeRateSnapshot)

            isLoaded = true

        } catch {
            self.error = error
        }
    }

    /// Completes the local Home snapshot with the latest FX snapshot when foreign
    /// currencies are present. A failed request leaves the already-safe partial or
    /// unavailable aggregation in place; it never restores a raw cross-currency sum.
    func refreshCurrencyAggregation() async {
        guard let windowStart = cachedWindowStart,
              let windowEnd = cachedWindowEnd
        else { return }

        let projections = spendProjections(from: cachedFinancialUpcoming, relativeTo: windowStart)
        guard aggregateRecurringSpend.requiresExchangeRates(
            projections: projections,
            reportingCurrencyCode: reportingCurrencyCode,
            range: windowStart..<windowEnd
        ) else { return }

        let revision = aggregationRevision

        do {
            let snapshot = try await loadExchangeRateSnapshot()
            guard !Task.isCancelled, revision == aggregationRevision else { return }
            exchangeRateSnapshot = snapshot
            rebuildPresentation(snapshot: snapshot)
        } catch is CancellationError {
            return
        } catch {
            // The no-snapshot presentation is already partial/unavailable and truthful.
        }
    }

    // MARK: - Aggregated presentation

    private func rebuildPresentation(snapshot: ExchangeRateSnapshot?) {
        guard let windowStart = cachedWindowStart,
              let windowEnd = cachedWindowEnd
        else { return }

        let projections = spendProjections(from: cachedFinancialUpcoming, relativeTo: windowStart)
        let forecastResult = aggregateRecurringSpend.execute(
            projections: projections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: windowStart..<windowEnd
        )
        forecastAggregation = forecastResult

        var dailyResults: [Date: RecurringSpendAggregationResult] = [:]
        for (day, items) in cachedItemsByDay {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            dailyResults[day] = aggregateRecurringSpend.execute(
                projections: spendProjections(from: items, relativeTo: windowStart),
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot,
                range: day..<dayEnd
            )
        }

        let dailyStates = dailyResults.mapValues(DailyFinancialState.init(aggregationResult:))
        let maxTotal = dailyStates.values.compactMap(\.numericAmount).max() ?? .zero
        let windowDays = 30

        landscapePoints = (0..<windowDays).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: windowStart) ?? windowStart
            let financialState = dailyStates[day] ?? .complete(amount: .zero)
            let normalized = financialState.numericAmount.map { total in
                maxTotal > 0
                    ? NSDecimalNumber(decimal: total / maxTotal).doubleValue
                    : 0
            }

            return BillingLandscapePoint(
                id: offset,
                date: day,
                financialState: financialState,
                normalizedHeight: normalized,
                currencyCode: reportingCurrencyCode,
                chargeCount: cachedItemsByDay[day]?.count ?? 0
            )
        }

        monthLabel = Self.monthYearFormatter
            .string(from: windowStart)
            .capitalized(with: PresentationLocale.current)
        forecastLabel = formattedForecast(forecastResult)

        if let selectedDate = selection?.date,
           let updatedSelection = makeSelection(for: selectedDate) {
            selection = updatedSelection
            callout = .selectedDay(updatedSelection)
            let selectedItems = cachedItemsByDay[selectedDate] ?? []
            calloutNavigationItem = selectedItems.count == 1 ? selectedItems[0] : nil
        } else {
            let nextItem = cachedFinancialUpcoming
                .filter {
                    $0.effectiveNextChargeDate(relativeTo: windowStart, calendar: calendar) >= windowStart
                }
                .min {
                    $0.effectiveNextChargeDate(relativeTo: windowStart, calendar: calendar)
                        < $1.effectiveNextChargeDate(relativeTo: windowStart, calendar: calendar)
                }
            callout = defaultCallout(nextItem: nextItem, now: windowStart)
            calloutNavigationItem = nextItem
        }

        insights = buildInsights(
            points: landscapePoints,
            trials: cachedTrials,
            currency: reportingCurrencyCode,
            canCompareSpend: forecastResult.isComplete
        )

        upcomingCharges = Array(
            cachedUpcoming
                .filter(\.status.countsInTotals)
                .prefix(3)
        )
    }

    private func spendProjections(
        from items: [RecurringItem],
        relativeTo windowStart: Date
    ) -> [RecurringSpendProjection] {
        items.map { item in
            RecurringSpendProjection(
                date: calendar.startOfDay(
                    for: item.effectiveNextChargeDate(relativeTo: windowStart, calendar: calendar)
                ),
                amount: item.amount,
                currencyCode: item.currencyCode
            )
        }
    }

    private func aggregate(
        items: [RecurringItem],
        on day: Date
    ) -> RecurringSpendAggregationResult {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let referenceDate = cachedWindowStart ?? day
        return aggregateRecurringSpend.execute(
            projections: spendProjections(from: items, relativeTo: referenceDate),
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: exchangeRateSnapshot,
            range: day..<dayEnd
        )
    }

    private func formattedForecast(_ result: RecurringSpendAggregationResult) -> String {
        switch result {
        case let .complete(total, _):
            return "\(formatted(amount: total.amount, currency: total.currencyCode)) \(String(localized: "прогноз"))"
        case let .partial(total, _, _):
            return "\(formatted(amount: total.amount, currency: total.currencyCode)) \(String(localized: "частичный прогноз"))"
        case .unavailable:
            return String(localized: "Прогноз недоступен")
        }
    }

    private func formattedAggregationAmount(_ result: RecurringSpendAggregationResult) -> String {
        switch result {
        case let .complete(total, _):
            return formatted(amount: total.amount, currency: total.currencyCode)
        case let .partial(total, _, _):
            return "\(formatted(amount: total.amount, currency: total.currencyCode)) · \(String(localized: "Частично"))"
        case .unavailable:
            return String(localized: "Курсы валют недоступны")
        }
    }

    // MARK: - Selection

    /// Select a day by date. Tapping the already-selected day deselects (toggle).
    func selectDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)

        // Toggle: same day deselects.
        if let current = selection, calendar.isDate(current.date, inSameDayAs: day) {
            clearSelection()
            return
        }

        let items = cachedItemsByDay[day] ?? []

        guard !items.isEmpty else {
            selection = nil
            calloutNavigationItem = nil
            callout = .emptyDay(formattedDate: Self.dayFormatter.string(from: date))
            return
        }

        guard let sel = makeSelection(for: day) else { return }
        selection = sel
        callout   = .selectedDay(sel)
        calloutNavigationItem = items.count == 1 ? items[0] : nil
    }

    private func makeSelection(for date: Date) -> BillingLandscapeSelection? {
        let day = calendar.startOfDay(for: date)
        let items = cachedItemsByDay[day] ?? []
        guard !items.isEmpty else { return nil }

        let charges = items.map {
            BillingLandscapeSelection.ChargeLineItem(
                id: $0.id,
                name: $0.title,
                amountFormatted: formatted(amount: $0.amount, currency: $0.currencyCode)
            )
        }

        let aggregation = aggregate(items: items, on: day)
        return BillingLandscapeSelection(
            date: day,
            formattedDate: Self.dayFormatter.string(from: day),
            charges: charges,
            financialState: DailyFinancialState(aggregationResult: aggregation),
            totalFormatted: formattedAggregationAmount(aggregation)
        )
    }

    func clearSelection() {
        guard selection != nil else { return }
        selection = nil
        let now      = Date.now
        let nextItem = cachedItemsByDay.values
            .flatMap { $0 }
            .filter { $0.effectiveNextChargeDate() >= calendar.startOfDay(for: now) }
            .min { $0.effectiveNextChargeDate() < $1.effectiveNextChargeDate() }
        callout = defaultCallout(nextItem: nextItem, now: now)
        calloutNavigationItem = nextItem
    }

    // MARK: - Callout builder

    private func defaultCallout(
        nextItem: RecurringItem?,
        now: Date
    ) -> NextPaymentCalloutState {
        guard let item = nextItem else {
            return .noUpcoming
        }
        let itemDate = item.effectiveNextChargeDate(relativeTo: now, calendar: calendar)
        let day = calendar.startOfDay(for: itemDate)
        let sameDay = cachedItemsByDay[day] ?? []
        // Show up to 3 names inline; overflow shown as "и ещё N".
        let visibleNames = sameDay.prefix(3).map(\.title).joined(separator: " · ")
        let overflow = max(0, sameDay.count - 3)
        return .nextPayment(
            countdown: countdownLabel(from: now, to: itemDate),
            name: visibleNames.isEmpty ? item.title : visibleNames,
            amountFormatted: formattedAggregationAmount(aggregate(items: sameDay, on: day)),
            additionalCount: overflow
        )
    }

    // MARK: - Insights builders

    private func buildInsights(
        points: [BillingLandscapePoint],
        trials: [RecurringItem],
        currency: String,
        canCompareSpend: Bool
    ) -> [InsightRowModel] {
        var rows: [InsightRowModel] = []
        if canCompareSpend,
           let r = peakWeekRow(points: points, currency: currency) { rows.append(r) }
        if let r = quietWindowRow(points: points)                   { rows.append(r) }
        if let r = trialRow(trials: trials)                         { rows.append(r) }
        return rows
    }

    private func peakWeekRow(points: [BillingLandscapePoint], currency: String) -> InsightRowModel? {
        struct WeekBucket { var total: Decimal; var start: Date; var end: Date }
        // Key must include yearForWeekOfYear — weekOfYear alone collides at year boundaries
        // (e.g. Dec 30 week-1 and Jan 3 week-1 map to the same Int).
        struct WeekKey: Hashable { let year: Int; let week: Int }
        var weeks: [WeekKey: WeekBucket] = [:]

        for point in points {
            guard let total = point.rawTotal else { continue }
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: point.date)
            let key = WeekKey(year: comps.yearForWeekOfYear ?? 0, week: comps.weekOfYear ?? 0)
            let existing = weeks[key]
            weeks[key] = WeekBucket(
                total: (existing?.total ?? 0) + total,
                start: min(existing?.start ?? point.date, point.date),
                end:   max(existing?.end   ?? point.date, point.date)
            )
        }

        guard let peak = weeks.values.max(by: { $0.total < $1.total }),
              peak.total > 0 else { return nil }

        return InsightRowModel(
            id: .peak,
            label: String(localized: "Пик расходов"),
            value: formatRange(peak.start, peak.end),
            amount: formatted(amount: peak.total, currency: currency),
            valueRole: .standard
        )
    }

    private func quietWindowRow(points: [BillingLandscapePoint]) -> InsightRowModel? {
        var bestStart: Date?
        var bestLength = 0
        var runStart: Date?
        var runLength = 0

        for point in points {
            if point.chargeCount == 0 {
                if runStart == nil { runStart = point.date }
                runLength += 1
                if runLength > bestLength {
                    bestLength = runLength
                    bestStart  = runStart
                }
            } else {
                runStart  = nil
                runLength = 0
            }
        }

        guard bestLength >= 3, let start = bestStart else { return nil }
        let end = calendar.date(byAdding: .day, value: bestLength - 1, to: start) ?? start

        return InsightRowModel(
            id: .quiet,
            label: String(localized: "Свободный период"),
            value: formatRange(start, end),
            amount: nil,
            valueRole: .quiet
        )
    }

    private func trialRow(trials: [RecurringItem]) -> InsightRowModel? {
        let cutoff = calendar.date(byAdding: .day, value: 14, to: .now) ?? .now
        guard let item = trials
            .filter({ ($0.trialEndDate ?? .distantFuture) <= cutoff })
            .min(by: { ($0.trialEndDate ?? .distantFuture) < ($1.trialEndDate ?? .distantFuture) }),
              let end = item.trialEndDate
        else { return nil }

        return InsightRowModel(
            id: .trial,
            label: String(localized: "Пробный период"),
            value: "\(item.title) · \(Self.dayFormatter.string(from: end))",
            amount: nil,
            valueRole: .warning
        )
    }

    // MARK: - Formatting helpers

    private static var currencyFormatters: [String: NumberFormatter] = [:]

    private func formatted(amount: Decimal, currency: String) -> String {
        let f: NumberFormatter
        if let cached = Self.currencyFormatters[currency] {
            f = cached
        } else {
            let new = NumberFormatter()
            new.numberStyle         = .currency
            new.currencyCode        = currency
            new.maximumFractionDigits = 2
            new.minimumFractionDigits = 0
            Self.currencyFormatters[currency] = new
            f = new
        }
        return f.string(for: amount) ?? "\(amount)"
    }

    private func formatRange(_ start: Date, _ end: Date) -> String {
        "\(Self.dayFormatter.string(from: start))–\(Self.dayFormatter.string(from: end))"
    }

    private func countdownLabel(from: Date, to: Date) -> String {
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        switch days {
        case 0:  return String(localized: "Сегодня")
        case 1:  return String(localized: "Завтра")
        default: return String(localized: "Через \(days) дн.")
        }
    }

    // MARK: - Static formatters

    private static let monthYearFormatter: DateFormatter = {
        PresentationLocale.dateFormatter(template: "LLLL yyyy")
    }()

    private static let dayFormatter: DateFormatter = {
        PresentationLocale.dateFormatter(template: "MMM d")
    }()
}
