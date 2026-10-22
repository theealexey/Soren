import Foundation

// MARK: - Monthly Projection

/// Projected total spend for a single calendar month, in reporting currency.
struct MonthlyProjection: Identifiable, Equatable {
    let month: Date
    let total: Decimal
    var id: Date { month }

    /// Short localized month label for the chart axis.
    var shortLabel: String {
        Self.labelFormatter.string(from: month)
    }

    /// `Decimal -> Double` bridge used only by Swift Charts.
    var doubleTotal: Double {
        NSDecimalNumber(decimal: total).doubleValue
    }

    private static let labelFormatter: DateFormatter = {
        let formatter = PresentationLocale.dateFormatter(template: "MMM", calendar: BillingCivilDay.calendar)
        formatter.timeZone = .gmt
        return formatter
    }()
}

/// Retains incomplete FX and schedule results without manufacturing chart zeros.
struct AnalyticsForecastMonthResult {
    let schedule: AnalyticsForecastMonth
    let aggregation: RecurringSpendAggregationResult

    var completeTotal: Decimal? {
        guard schedule.monetaryCompleteness == .complete, aggregation.isComplete else { return nil }
        return aggregation.total?.amount
    }
}

// MARK: - Comparative Spend Models

/// Complete monthly spend for one category, normalized to reporting currency.
struct CategorySpend: Identifiable, Equatable {
    let category: ItemCategory
    let monthlyTotal: Decimal
    let itemCount: Int
    /// Share of the complete monthly total: 0.0 ... 1.0.
    let proportion: Double

    var id: String { category.rawValue }
}

/// Complete monthly spend for one provider, normalized to reporting currency.
struct ProviderSpend: Identifiable, Equatable {
    let id: String
    let name: String
    let monthlyTotal: Decimal
    let itemCount: Int
}

/// Comparable change between two projected months in one reporting currency.
struct AnalyticsTrendComparison: Equatable {
    let earlierMonth: Date
    let laterMonth: Date
    let earlierTotal: Decimal
    let laterTotal: Decimal
    let delta: Decimal
    let currencyCode: String
}

// MARK: - Top Spend Row Model

/// Pre-computed reporting-currency contribution for Top Subscriptions.
/// `navigationItem` retains the original authoritative amount and currency.
struct TopSpendRowModel: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let monthlyAmount: Decimal
    let currency: String
    let providerTemplate: ProviderTemplate?
    let category: ItemCategory
    let navigationItem: RecurringItem
}

// MARK: - Analytics View Model

/// Preserves the current-obligation normalized summary and an independent complete schedule
/// population, sharing one exchange-rate snapshot per calculation revision.
@MainActor @Observable
final class AnalyticsViewModel {

    // MARK: - State

    private(set) var screenState: AnalyticsScreenState = .empty
    private(set) var isLoaded = false
    private(set) var error: Error?
    /// Drives one cancellable SwiftUI task per Analytics calculation.
    private(set) var aggregationRevision = 0

    // MARK: - Dependencies

    private let getCurrentObligations: GetAnalyticsCurrentObligations
    private let getForecast: GetAnalyticsForecast
    private let preferences: UserPreferencesRepository
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let exchangeRateProvider: any ExchangeRateProvider

    // MARK: - Revision State

    private var items: [RecurringItem] = []
    private var forecast: [AnalyticsForecastMonth] = []
    private var calculationToday: CivilDate?
    private var reportingCurrencyCode = UserPreferences.default.defaultCurrencyCode
    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var inFlightRevision: Int?

    // MARK: - Stable Calculation Context

    /// Monthly-normalized values are not tied to a real charge date. A fixed range
    /// lets every grouping use the canonical dated aggregation API consistently.
    private static let normalizedProjectionDate = Date(timeIntervalSinceReferenceDate: 0)
    private static let normalizedProjectionRange: Range<Date> = {
        let start = normalizedProjectionDate
        return start..<start.addingTimeInterval(1)
    }()

    // MARK: - Init

    init(
        getCurrentObligations: GetAnalyticsCurrentObligations,
        getForecast: GetAnalyticsForecast,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        now: @escaping () -> Date = { .now },
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.getCurrentObligations = getCurrentObligations
        self.getForecast = getForecast
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.exchangeRateProvider = exchangeRateProvider
        self.now = now
        self.timeZone = timeZone
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }

        aggregationRevision += 1
        exchangeRateSnapshot = nil
        error = nil

        do {
            reportingCurrencyCode = preferences.load().defaultCurrencyCode
            let localToday = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
            let currentObligations = try getCurrentObligations.execute(today: localToday)
            let forecast = try getForecast.execute(today: localToday)
            items = currentObligations
            self.forecast = forecast
            calculationToday = localToday
            rebuildScreenState(snapshot: nil, today: localToday)
            isLoaded = true
        } catch {
            self.error = error
        }
    }

    /// Compatibility entry point retained for the existing category integration test.
    /// It now follows the same revision-safe load path as production Analytics.
    func loadLocalData(forceReload: Bool = false) {
        load(forceReload: forceReload)
    }

    /// Fetches at most one shared snapshot concurrently for the active Analytics revision.
    /// Every monetary grouping is then rebuilt from that exact snapshot.
    func refreshCurrencyAggregation(revision: Int) async {
        guard revision == aggregationRevision,
              exchangeRateSnapshot == nil,
              currentCalculationRequiresExchangeRates(),
              inFlightRevision != revision
        else { return }

        inFlightRevision = revision
        defer {
            if inFlightRevision == revision {
                inFlightRevision = nil
            }
        }

        do {
            let snapshot = try await exchangeRateProvider.latestSnapshot()
            guard !Task.isCancelled, revision == aggregationRevision,
                  let calculationToday else { return }
            exchangeRateSnapshot = snapshot
            rebuildScreenState(snapshot: snapshot, today: calculationToday)
        } catch is CancellationError {
            return
        } catch {
            // The no-snapshot state is already truthful: foreign values remain
            // missing instead of being added as raw numbers in reporting currency.
        }
    }

    // MARK: - State Construction

    private func rebuildScreenState(snapshot: ExchangeRateSnapshot?, today: CivilDate) {
        let annualItems = buildAnnualItems(today: today)
        let monthlyAggregation = aggregateMonthly(items, snapshot: snapshot)
        let forecastMonths = forecast.map { month in
            AnalyticsForecastMonthResult(schedule: month, aggregation: aggregateRecurringSpend.execute(
                projections: month.charges, reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot, range: month.range
            ))
        }
        let projections = buildProjections(forecastMonths)
        let monthlyTotal = monthlyAggregation.total?.amount ?? .zero
        let unusedItems = items.filter { $0.usageStatus == .unused }
        let summary = DashboardSummary(
            monthlyTotal: monthlyTotal,
            yearlyProjection: monthlyTotal * 12,
            activeItemCount: items.count,
            activeTrialCount: items.filter { $0.status == .trial }.count,
            containsMixedCurrencies: Set(items.map(\.currencyCode)).count > 1,
            ratesAvailable: monthlyAggregation.rateMetadata != nil
        )

        guard monthlyAggregation.isComplete else {
            screenState = AnalyticsScreenState(
                summary: summary,
                monthlyAggregation: monthlyAggregation,
                categoryBreakdown: [],
                providerBreakdown: [],
                monthlyProjections: projections,
                forecastMonths: forecastMonths,
                trendComparison: buildTrendComparison(projections),
                topItems: [],
                annualItems: annualItems,
                unusedItems: unusedItems,
                defaultCurrency: reportingCurrencyCode,
                unusedMonthlyCost: nil
            )
            return
        }

        let categoryBreakdown = buildCategoryBreakdown(items, grandTotal: monthlyTotal, snapshot: snapshot)
        let providerBreakdown = buildProviderBreakdown(items, snapshot: snapshot)

        screenState = AnalyticsScreenState(
            summary: summary,
            monthlyAggregation: monthlyAggregation,
            categoryBreakdown: categoryBreakdown,
            providerBreakdown: providerBreakdown,
            monthlyProjections: projections,
            forecastMonths: forecastMonths,
            trendComparison: buildTrendComparison(projections),
            topItems: buildTopRows(items, snapshot: snapshot),
            annualItems: annualItems,
            unusedItems: unusedItems,
            defaultCurrency: reportingCurrencyCode,
            unusedMonthlyCost: aggregateMonthly(unusedItems, snapshot: snapshot).total?.amount
        )
    }

    private func buildAnnualItems(today: CivilDate) -> [AnalyticsAnnualRow] {
        let projector = RecurringScheduleProjector()
        return items.filter { $0.billingCycle == .annual }.map { item in
            do {
                guard let date = try projector.nextScheduledCharge(for: item, onOrAfter: today) else {
                    return AnalyticsAnnualRow(item: item, chargeState: .absent,
                        subtitle: String(localized: "analytics.annual.notScheduled"), projectionError: nil)
                }
                let days = try BillingCivilDay.days(from: today, to: date)
                let dateText = Self.annualDateFormatter.string(from: try BillingCivilDay.canonicalDate(for: date))
                let subtitle: String
                if days == 0 {
                    subtitle = String(localized: "Сегодня")
                } else if days <= 30 {
                    subtitle = String(localized: "Через \(days) дн. — \(dateText)")
                } else {
                    subtitle = dateText
                }
                return AnalyticsAnnualRow(item: item, chargeState: .found(date),
                    subtitle: subtitle, projectionError: nil)
            } catch {
                return AnalyticsAnnualRow(item: item, chargeState: .unavailable,
                    subtitle: String(localized: "analytics.annual.unavailable"), projectionError: error)
            }
        }.sorted { lhs, rhs in
            switch (lhs.chargeState, rhs.chargeState) {
            case let (.found(left), .found(right)) where left != right: return left < right
            case (.found, .unavailable), (.found, .absent), (.unavailable, .absent): return true
            case (.unavailable, .found), (.absent, .found), (.absent, .unavailable): return false
            default: return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    private static let annualDateFormatter: DateFormatter = {
        let formatter = PresentationLocale.dateFormatter(template: "d MMMM", calendar: BillingCivilDay.calendar)
        formatter.timeZone = .gmt
        return formatter
    }()

    private func aggregateMonthly(
        _ items: [RecurringItem],
        snapshot: ExchangeRateSnapshot?
    ) -> RecurringSpendAggregationResult {
        aggregateRecurringSpend.execute(
            projections: items.map(monthlyProjection(for:)),
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: Self.normalizedProjectionRange
        )
    }

    private func monthlyProjection(for item: RecurringItem) -> RecurringSpendProjection {
        RecurringSpendProjection(
            date: Self.normalizedProjectionDate,
            amount: item.monthlyEquivalent,
            currencyCode: item.currencyCode
        )
    }

    private func currentCalculationRequiresExchangeRates() -> Bool {
        aggregateRecurringSpend.requiresExchangeRates(
            projections: items.map(monthlyProjection(for:)),
            reportingCurrencyCode: reportingCurrencyCode,
            range: Self.normalizedProjectionRange
        ) || forecast.contains { month in
            aggregateRecurringSpend.requiresExchangeRates(
                projections: month.charges, reportingCurrencyCode: reportingCurrencyCode, range: month.range
            )
        }
    }

    // MARK: - Complete-only Comparisons

    private func buildCategoryBreakdown(
        _ items: [RecurringItem],
        grandTotal: Decimal,
        snapshot: ExchangeRateSnapshot?
    ) -> [CategorySpend] {
        guard grandTotal > .zero else { return [] }

        let grouped = Dictionary(grouping: items, by: \.category)
        return grouped.compactMap { category, categoryItems in
            let result = aggregateMonthly(categoryItems, snapshot: snapshot)
            guard result.isComplete, let total = result.total else { return nil }
            return CategorySpend(
                category: category,
                monthlyTotal: total.amount,
                itemCount: categoryItems.count,
                proportion: NSDecimalNumber(decimal: total.amount / grandTotal).doubleValue
            )
        }
        .sorted { $0.monthlyTotal > $1.monthlyTotal }
    }

    private struct ProviderGroup {
        let id: String
        let name: String
        var items: [RecurringItem]
    }

    private func buildProviderBreakdown(
        _ items: [RecurringItem],
        snapshot: ExchangeRateSnapshot?
    ) -> [ProviderSpend] {
        var groups: [String: ProviderGroup] = [:]
        for item in items {
            let id = item.providerID ?? "manual:\(item.providerName)"
            if var group = groups[id] {
                group.items.append(item)
                groups[id] = group
            } else {
                groups[id] = ProviderGroup(id: id, name: item.providerName, items: [item])
            }
        }

        return groups.values.compactMap { group in
            let result = aggregateMonthly(group.items, snapshot: snapshot)
            guard result.isComplete, let total = result.total else { return nil }
            return ProviderSpend(
                id: group.id,
                name: group.name,
                monthlyTotal: total.amount,
                itemCount: group.items.count
            )
        }
        .sorted { $0.monthlyTotal > $1.monthlyTotal }
    }

    private func buildTopRows(
        _ items: [RecurringItem],
        snapshot: ExchangeRateSnapshot?
    ) -> [TopSpendRowModel] {
        items.compactMap { item in
            let result = aggregateMonthly([item], snapshot: snapshot)
            guard result.isComplete, let total = result.total else { return nil }
            return TopSpendRowModel(
                id: item.id,
                title: item.title,
                subtitle: item.providerName == item.title ? nil : item.providerName,
                monthlyAmount: total.amount,
                currency: total.currencyCode,
                providerTemplate: item.providerTemplate,
                category: item.category,
                navigationItem: item
            )
        }
        .sorted { $0.monthlyAmount > $1.monthlyAmount }
        .prefix(5)
        .map { $0 }
    }

    private func buildTrendComparison(
        _ projections: [MonthlyProjection]
    ) -> AnalyticsTrendComparison? {
        guard projections.count >= 2 else { return nil }
        let earlier = projections[0]
        let later = projections[1]
        return AnalyticsTrendComparison(
            earlierMonth: earlier.month,
            laterMonth: later.month,
            earlierTotal: earlier.total,
            laterTotal: later.total,
            delta: later.total - earlier.total,
            currencyCode: reportingCurrencyCode
        )
    }

    // MARK: - Forecast

    private let now: () -> Date
    private let timeZone: () -> TimeZone

    var today: CivilDate? { try? BillingCivilDay.civilDate(containing: now(), in: timeZone()) }

    private func buildProjections(
        _ months: [AnalyticsForecastMonthResult]
    ) -> [MonthlyProjection] {
        var result: [MonthlyProjection] = []
        for month in months {
            guard let total = month.completeTotal else { return [] }
            result.append(MonthlyProjection(month: month.schedule.range.lowerBound, total: total))
        }
        return result
    }
}
