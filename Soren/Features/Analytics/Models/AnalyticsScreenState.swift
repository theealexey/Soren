import Foundation

enum AnalyticsAnnualChargeState: Equatable {
    case found(CivilDate)
    case absent
    case unavailable
}

struct AnalyticsAnnualRow: Identifiable {
    let item: RecurringItem
    let chargeState: AnalyticsAnnualChargeState
    let subtitle: String
    let projectionError: Error?

    var id: UUID { item.id }
}

// MARK: - Analytics Screen State

/// Complete value-type snapshot of all Analytics tab outputs.
/// Built atomically by AnalyticsViewModel. Normalized sections use current
/// non-trial obligations; forecast uses all canonical schedule candidates.
///
/// Mirrors the HomeScreenState pattern: ViewModel exposes one state root;
/// AnalyticsView reads exclusively from screenState.
struct AnalyticsScreenState {
    let summary: DashboardSummary
    /// Canonical reporting-currency result for the monthly normalized spend.
    /// This distinguishes a genuine zero from partial or unavailable FX data.
    let monthlyAggregation: RecurringSpendAggregationResult?
    let categoryBreakdown: [CategorySpend]
    /// Complete-only provider grouping retained for ranking/comparison consumers.
    let providerBreakdown: [ProviderSpend]
    let monthlyProjections: [MonthlyProjection]
    let forecastMonths: [AnalyticsForecastMonthResult]
    /// Complete-only comparable trend derived from reporting-currency projections.
    let trendComparison: AnalyticsTrendComparison?
    let topItems: [TopSpendRowModel]
    let annualItems: [AnalyticsAnnualRow]
    let unusedItems: [RecurringItem]
    let defaultCurrency: String
    /// Pre-computed total monthly cost of unused items.
    /// Stored rather than computed to avoid requiring exchange-rate access on the struct.
    let unusedMonthlyCost: Decimal?
    var annualAggregation: RecurringSpendAggregationResult? = nil
    /// Separate from missing FX; no normalized subtotal is valid after this failure.
    var normalizationError: Error? = nil

    var includedItemCount: Int { summary.activeItemCount }

    func includedCountLabel(locale: Locale = PresentationLocale.current, bundle: Bundle = .main) -> String {
        let count = includedItemCount.formatted(.number.locale(locale))
        return String(localized: "analytics.includedCount \(count)", bundle: bundle, locale: locale)
    }

    /// Empty is a source-data fact, never an alias for failed FX aggregation.
    var isEmpty: Bool {
        summary.activeItemCount == 0 && forecastMonths.allSatisfy {
            $0.schedule.eventCount == 0 && $0.schedule.monetaryCompleteness == .complete
        }
    }

    static let empty = AnalyticsScreenState(
        summary: .empty,
        monthlyAggregation: nil,
        categoryBreakdown: [],
        providerBreakdown: [],
        monthlyProjections: [],
        forecastMonths: [],
        trendComparison: nil,
        topItems: [] as [TopSpendRowModel],
        annualItems: [],
        unusedItems: [],
        defaultCurrency: UserPreferences.default.defaultCurrencyCode,
        unusedMonthlyCost: nil
    )
}
