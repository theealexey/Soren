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
        PresentationLocale.dateFormatter(template: "MMM")
    }()
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

/// Drives the Analytics tab from one recurring-item snapshot and, when needed,
/// one exchange-rate snapshot per calculation revision.
@MainActor @Observable
final class AnalyticsViewModel {

    // MARK: - State

    private(set) var screenState: AnalyticsScreenState = .empty
    private(set) var isLoaded = false
    private(set) var error: Error?
    /// Drives one cancellable SwiftUI task per Analytics calculation.
    private(set) var aggregationRevision = 0

    // MARK: - Dependencies

    private let getActiveItems: GetActiveItems
    private let preferences: UserPreferencesRepository
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let exchangeRateProvider: any ExchangeRateProvider

    // MARK: - Revision State

    private var items: [RecurringItem] = []
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

    private static let cal: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = PresentationLocale.current
        calendar.timeZone = .current
        return calendar
    }()

    // MARK: - Init

    init(
        getActiveItems: GetActiveItems,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider()
    ) {
        self.getActiveItems = getActiveItems
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.exchangeRateProvider = exchangeRateProvider
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }

        aggregationRevision += 1
        exchangeRateSnapshot = nil
        error = nil

        do {
            reportingCurrencyCode = preferences.load().defaultCurrencyCode
            items = try getActiveItems.execute()
            rebuildScreenState(snapshot: nil)
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
            guard !Task.isCancelled, revision == aggregationRevision else { return }
            exchangeRateSnapshot = snapshot
            rebuildScreenState(snapshot: snapshot)
        } catch is CancellationError {
            return
        } catch {
            // The no-snapshot state is already truthful: foreign values remain
            // missing instead of being added as raw numbers in reporting currency.
        }
    }

    // MARK: - State Construction

    private func rebuildScreenState(snapshot: ExchangeRateSnapshot?) {
        let monthlyAggregation = aggregateMonthly(items, snapshot: snapshot)
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
                monthlyProjections: [],
                trendComparison: nil,
                topItems: [],
                annualItems: annualItems,
                unusedItems: unusedItems,
                defaultCurrency: reportingCurrencyCode,
                unusedMonthlyCost: nil
            )
            return
        }

        let projections = buildProjections(items, snapshot: snapshot)
        let categoryBreakdown = buildCategoryBreakdown(items, grandTotal: monthlyTotal, snapshot: snapshot)
        let providerBreakdown = buildProviderBreakdown(items, snapshot: snapshot)

        screenState = AnalyticsScreenState(
            summary: summary,
            monthlyAggregation: monthlyAggregation,
            categoryBreakdown: categoryBreakdown,
            providerBreakdown: providerBreakdown,
            monthlyProjections: projections,
            trendComparison: buildTrendComparison(projections),
            topItems: buildTopRows(items, snapshot: snapshot),
            annualItems: annualItems,
            unusedItems: unusedItems,
            defaultCurrency: reportingCurrencyCode,
            unusedMonthlyCost: aggregateMonthly(unusedItems, snapshot: snapshot).total?.amount
        )
    }

    private var annualItems: [RecurringItem] {
        items.filter {
            if case .annual = $0.billingCycle { return true }
            return false
        }
    }

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
        )
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

    private func buildProjections(
        _ items: [RecurringItem],
        snapshot: ExchangeRateSnapshot?,
        months: Int = 6
    ) -> [MonthlyProjection] {
        let calendar = Self.cal
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: .now)
        ) else { return [] }

        var result: [MonthlyProjection] = []
        for offset in 0..<months {
            guard let start = calendar.date(byAdding: .month, value: offset, to: monthStart),
                  let end = calendar.date(byAdding: .month, value: 1, to: start)
            else { return [] }

            let projections = items.compactMap { item -> RecurringSpendProjection? in
                let amount: Decimal
                if item.billingCycle.isLongCycle {
                    guard hasCharge(item, from: start, to: end) else { return nil }
                    amount = item.amount
                } else {
                    amount = item.monthlyEquivalent
                }
                return RecurringSpendProjection(
                    date: start,
                    amount: amount,
                    currencyCode: item.currencyCode
                )
            }

            let aggregation = aggregateRecurringSpend.execute(
                projections: projections,
                reportingCurrencyCode: reportingCurrencyCode,
                snapshot: snapshot,
                range: start..<end
            )
            guard aggregation.isComplete, let total = aggregation.total else { return [] }
            result.append(MonthlyProjection(month: start, total: total.amount))
        }
        return result
    }

    private func hasCharge(_ item: RecurringItem, from start: Date, to end: Date) -> Bool {
        let calendar = Self.cal
        let cycleMonths: Int
        switch item.billingCycle {
        case .quarterly: cycleMonths = 3
        case .semiannual: cycleMonths = 6
        case .annual: cycleMonths = 12
        default: return true
        }

        var check = item.nextChargeDate
        while check >= end {
            guard let previous = calendar.date(byAdding: .month, value: -cycleMonths, to: check) else {
                return false
            }
            check = previous
        }
        while check < start {
            guard let next = calendar.date(byAdding: .month, value: cycleMonths, to: check) else {
                return false
            }
            check = next
        }
        return check >= start && check < end
    }
}
