import Foundation

// MARK: - Dashboard Summary

/// Aggregated financial snapshot for the Home screen.
/// Computed from active recurring items — no persistence needed.
struct DashboardSummary: Equatable, Sendable {
    /// Total monthly cost across all active items (converted to target currency if rates available).
    let monthlyTotal: Decimal
    /// Projected yearly cost (monthlyTotal × 12).
    let yearlyProjection: Decimal
    /// Number of active (non-archived, non-cancelled) items.
    let activeItemCount: Int
    /// Number of active trials.
    let activeTrialCount: Int
    /// True if subscriptions span multiple currencies.
    let containsMixedCurrencies: Bool
    /// True if exchange rates were available for conversion.
    let ratesAvailable: Bool

    static let empty = DashboardSummary(
        monthlyTotal: 0,
        yearlyProjection: 0,
        activeItemCount: 0,
        activeTrialCount: 0,
        containsMixedCurrencies: false,
        ratesAvailable: false
    )
}
