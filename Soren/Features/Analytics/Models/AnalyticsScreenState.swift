import Foundation

// MARK: - Analytics Screen State

/// Complete value-type snapshot of all Analytics tab outputs.
/// Built atomically by AnalyticsViewModel.loadLocalData() — every field
/// is derived from the same [RecurringItem] array, so counts and totals
/// across sections are guaranteed to be consistent.
///
/// Mirrors the HomeScreenState pattern: ViewModel exposes one state root;
/// AnalyticsView reads exclusively from screenState.
struct AnalyticsScreenState {
    let summary: DashboardSummary
    let categoryBreakdown: [CategorySpend]
    let monthlyProjections: [MonthlyProjection]
    let topItems: [TopSpendRowModel]
    let annualItems: [RecurringItem]
    let unusedItems: [RecurringItem]
    let defaultCurrency: String
    /// Pre-computed total monthly cost of unused items.
    /// Stored rather than computed to avoid requiring exchange-rate access on the struct.
    let unusedMonthlyCost: Decimal

    var isEmpty: Bool { summary == .empty }

    static let empty = AnalyticsScreenState(
        summary: .empty,
        categoryBreakdown: [],
        monthlyProjections: [],
        topItems: [] as [TopSpendRowModel],
        annualItems: [],
        unusedItems: [],
        defaultCurrency: UserPreferences.default.defaultCurrencyCode,
        unusedMonthlyCost: .zero
    )
}
