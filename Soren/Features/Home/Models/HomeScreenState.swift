import Foundation

// MARK: - Home Screen State

/// Screen-level FX presentation state derived from rates that actually
/// contributed to the current Home aggregates.
enum HomeExchangeRateNotice: Equatable {
    case none
    case stale(age: TimeInterval)
}

/// Snapshot of all data needed to render the Home screen.
/// Produced by HomeViewModel as a computed property.
/// Useful for unit testing (assert on whole state) and SwiftUI previews.
struct HomeScreenState {
    let monthLabel: String
    let forecastLabel: String
    let forecastAggregation: RecurringSpendAggregationResult?
    let exchangeRateNotice: HomeExchangeRateNotice
    let landscapePoints: [BillingLandscapePoint]
    let callout: NextPaymentCalloutState
    let calloutNavigationItem: RecurringItem?
    let insights: [InsightRowModel]
    let upcomingCharges: [RecurringItem]
    let isLoaded: Bool
    let hasError: Bool
}
