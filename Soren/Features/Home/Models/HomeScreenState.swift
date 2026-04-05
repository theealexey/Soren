import Foundation

// MARK: - Home Screen State

/// Snapshot of all data needed to render the Home screen.
/// Produced by HomeViewModel as a computed property.
/// Useful for unit testing (assert on whole state) and SwiftUI previews.
struct HomeScreenState {
    let monthLabel: String
    let forecastLabel: String
    let landscapePoints: [BillingLandscapePoint]
    let callout: NextPaymentCalloutState
    let insights: [InsightRowModel]
    let isLoaded: Bool
    let hasError: Bool
}
