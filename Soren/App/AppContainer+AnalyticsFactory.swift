import Foundation

// MARK: - AppContainer + Analytics Factory

/// Composition root for the Analytics feature.
/// The only site in the app that wires AnalyticsViewModel's explicit dependencies.
/// AnalyticsViewModel itself has no knowledge of AppContainer or RepositoryContainer.
extension AppContainer {
    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(
            getCurrentObligations: GetAnalyticsCurrentObligations(repository: repositories.recurringItems),
            getForecast: GetAnalyticsForecast(repository: repositories.recurringItems),
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: exchangeRateProvider
        )
    }
}
