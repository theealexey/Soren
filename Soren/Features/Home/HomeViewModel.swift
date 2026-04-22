import Foundation

// MARK: - Home View Model

/// Drives the Billing Landscape Home screen.
/// Receives explicit use-case dependencies — no RepositoryContainer or AppContainer access.
/// All output is value types (String, Decimal, structs). No SwiftUI types returned.
@MainActor @Observable
final class HomeViewModel {

    // MARK: - Output

    private(set) var monthLabel: String = ""
    private(set) var forecastLabel: String = ""
    private(set) var landscapePoints: [BillingLandscapePoint] = []
    private(set) var callout: NextPaymentCalloutState = .nextPayment(
        countdown: "", name: "", amountFormatted: "", additionalCount: 0
    )
    private(set) var insights: [InsightRowModel] = []
    private(set) var selection: BillingLandscapeSelection? = nil
    private(set) var isLoaded = false
    private(set) var error: Error? = nil

    var hasError: Bool { error != nil }

    /// Full snapshot — useful for unit tests and SwiftUI previews.
    var screenState: HomeScreenState {
        HomeScreenState(
            monthLabel: monthLabel,
            forecastLabel: forecastLabel,
            landscapePoints: landscapePoints,
            callout: callout,
            insights: insights,
            isLoaded: isLoaded,
            hasError: hasError
        )
    }

    // MARK: - Dependencies

    private let getUpcomingCharges: GetUpcomingCharges
    private let getActiveTrials: GetActiveTrials
    private let preferences: UserPreferencesRepository

    // MARK: - Cache

    /// Populated on load. Enables instant selectDate() without a repository hit.
    private var cachedItemsByDay: [Date: [RecurringItem]] = [:]

    private let calendar = Calendar.current

    // MARK: - Init

    init(
        getUpcomingCharges: GetUpcomingCharges,
        getActiveTrials: GetActiveTrials,
        preferences: UserPreferencesRepository
    ) {
        self.getUpcomingCharges = getUpcomingCharges
        self.getActiveTrials = getActiveTrials
        self.preferences = preferences
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        error = nil
        selection = nil

        do {
            let now = Date.now
            // Window starts at the beginning of today so charges scheduled at 00:00
            // (or any earlier time today) are included. Exact Date.now would exclude them.
            let windowStart = calendar.startOfDay(for: now)
            let windowDays = 30

            // Expired finite subscriptions (autoRenew=false, endDate past) are excluded from
            // the active forecast so they don't inflate upcoming totals or landscape bars.
            let upcoming = try getUpcomingCharges.execute(days: windowDays, from: windowStart)
                .filter { !$0.isExpired }
            let trials   = try getActiveTrials.execute()

            // Use the items' own currency when all upcoming charges share one currency.
            // Fall back to the user preference only for mixed-currency portfolios
            // (proper cross-currency conversion is deferred work).
            let upcomingCurrencies = Set(upcoming.map(\.currencyCode))
            let currency = upcomingCurrencies.count == 1
                ? upcomingCurrencies.first!
                : preferences.load().defaultCurrencyCode

            // Group by effective charge date so rolled-forward items land in the correct bucket.
            let grouped: [Date: [RecurringItem]] = Dictionary(
                grouping: upcoming,
                by: { calendar.startOfDay(for: $0.effectiveNextChargeDate()) }
            )
            cachedItemsByDay = grouped

            let dailyTotals: [Date: Decimal] = grouped.mapValues { items in
                items.reduce(0) { $0 + $1.amount }
            }
            let maxTotal = dailyTotals.values.max() ?? 1

            landscapePoints = (0..<windowDays).map { offset in
                let day   = calendar.date(byAdding: .day, value: offset, to: windowStart)!
                let total = dailyTotals[day] ?? 0
                let count = grouped[day]?.count ?? 0
                let normalized: Double = maxTotal > 0
                    ? Double(truncating: (total / maxTotal) as NSDecimalNumber)
                    : 0.0
                return BillingLandscapePoint(
                    id: offset,
                    date: day,
                    normalizedHeight: normalized,
                    rawTotal: total,
                    currencyCode: currency,
                    chargeCount: count
                )
            }

            monthLabel   = Self.monthYearFormatter.string(from: now).capitalized
            let forecast = dailyTotals.values.reduce(Decimal(0), +)
            forecastLabel = "\(formatted(amount: forecast, currency: currency)) \(String(localized: "forecast"))"

            // Use effective date so rolled-forward items rank correctly in the callout.
            let nextItem = upcoming
                .filter { $0.effectiveNextChargeDate() >= windowStart }
                .min { $0.effectiveNextChargeDate() < $1.effectiveNextChargeDate() }
            callout = defaultCallout(nextItem: nextItem, now: now, currency: currency)

            insights = buildInsights(
                points: landscapePoints,
                trials: trials,
                currency: currency
            )

            isLoaded = true

        } catch {
            self.error = error
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
            callout = .emptyDay(formattedDate: Self.dayFormatter.string(from: date))
            return
        }

        let charges = items.map {
            BillingLandscapeSelection.ChargeLineItem(
                id: $0.id,
                name: $0.title,
                amountFormatted: formatted(amount: $0.amount, currency: $0.currencyCode)
            )
        }
        let total    = items.reduce(Decimal(0)) { $0 + $1.amount }
        let currency = items.first?.currencyCode ?? preferences.load().defaultCurrencyCode

        let sel = BillingLandscapeSelection(
            date: day,
            formattedDate: Self.dayFormatter.string(from: date),
            charges: charges,
            totalFormatted: formatted(amount: total, currency: currency)
        )
        selection = sel
        callout   = .selectedDay(sel)
    }

    func clearSelection() {
        guard selection != nil else { return }
        selection = nil
        let now      = Date.now
        let currency = preferences.load().defaultCurrencyCode
        let nextItem = cachedItemsByDay.values
            .flatMap { $0 }
            .filter { $0.effectiveNextChargeDate() >= calendar.startOfDay(for: now) }
            .min { $0.effectiveNextChargeDate() < $1.effectiveNextChargeDate() }
        callout = defaultCallout(nextItem: nextItem, now: now, currency: currency)
    }

    // MARK: - Callout builder

    private func defaultCallout(
        nextItem: RecurringItem?,
        now: Date,
        currency: String
    ) -> NextPaymentCalloutState {
        guard let item = nextItem else {
            return .noUpcoming
        }
        let sameDay = cachedItemsByDay[calendar.startOfDay(for: item.effectiveNextChargeDate())] ?? []
        // Show up to 3 names inline; overflow shown as "и ещё N".
        let visibleNames = sameDay.prefix(3).map(\.title).joined(separator: " · ")
        let overflow = max(0, sameDay.count - 3)
        return .nextPayment(
            countdown: countdownLabel(from: now, to: item.effectiveNextChargeDate()),
            name: visibleNames.isEmpty ? item.title : visibleNames,
            amountFormatted: formatted(amount: item.amount, currency: item.currencyCode),
            additionalCount: overflow
        )
    }

    // MARK: - Insights builders

    private func buildInsights(
        points: [BillingLandscapePoint],
        trials: [RecurringItem],
        currency: String
    ) -> [InsightRowModel] {
        var rows: [InsightRowModel] = []
        if let r = peakWeekRow(points: points, currency: currency) { rows.append(r) }
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
            let comps = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: point.date)
            let key = WeekKey(year: comps.yearForWeekOfYear ?? 0, week: comps.weekOfYear ?? 0)
            let existing = weeks[key]
            weeks[key] = WeekBucket(
                total: (existing?.total ?? 0) + point.rawTotal,
                start: min(existing?.start ?? point.date, point.date),
                end:   max(existing?.end   ?? point.date, point.date)
            )
        }

        guard let peak = weeks.values.max(by: { $0.total < $1.total }),
              peak.total > 0 else { return nil }

        return InsightRowModel(
            id: .peak,
            label: String(localized: "Peak week"),
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
            label: String(localized: "Clear runway"),
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
            label: String(localized: "Trial ending"),
            value: "\(item.title) · \(Self.dayFormatter.string(from: end))",
            amount: nil,
            valueRole: .warning
        )
    }

    // MARK: - Formatting helpers

    private func formatted(amount: Decimal, currency: String) -> String {
        let f = NumberFormatter()
        f.numberStyle       = .currency
        f.currencyCode      = currency
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(for: amount) ?? "\(amount)"
    }

    private func formatRange(_ start: Date, _ end: Date) -> String {
        "\(Self.dayFormatter.string(from: start))–\(Self.dayFormatter.string(from: end))"
    }

    private func countdownLabel(from: Date, to: Date) -> String {
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        switch days {
        case 0:  return String(localized: "Today")
        case 1:  return String(localized: "Tomorrow")
        default: return String(localized: "In \(days) days")
        }
    }

    // MARK: - Static formatters

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}
