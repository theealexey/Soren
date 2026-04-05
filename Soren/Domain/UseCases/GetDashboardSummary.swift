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

// MARK: - Use Case

/// Computes the dashboard financial summary from a pre-fetched item list.
/// Pure computation — no repository access. Caller owns the single fetch.
struct GetDashboardSummary {

    /// Compute summary with optional currency conversion.
    /// - Parameter items: Active recurring items, fetched once by the caller.
    func execute(
        items: [RecurringItem],
        targetCurrency: String? = nil,
        rates: ExchangeRates? = nil
    ) -> DashboardSummary {
        let currencies = Set(items.map(\.currencyCode))
        let isMixed = currencies.count > 1
        let hasRates = rates != nil && rates != .empty

        let monthlyTotal: Decimal
        if let target = targetCurrency, let rates {
            monthlyTotal = items.reduce(Decimal.zero) { sum, item in
                let converted = rates.convert(item.monthlyEquivalent, from: item.currencyCode, to: target)
                return sum + (converted ?? item.monthlyEquivalent)
            }
        } else {
            monthlyTotal = items.reduce(Decimal.zero) { sum, item in
                sum + item.monthlyEquivalent
            }
        }

        let trialCount = items.filter { $0.status == .trial }.count

        return DashboardSummary(
            monthlyTotal: monthlyTotal,
            yearlyProjection: monthlyTotal * 12,
            activeItemCount: items.count,
            activeTrialCount: trialCount,
            containsMixedCurrencies: isMixed,
            ratesAvailable: hasRates
        )
    }
}
