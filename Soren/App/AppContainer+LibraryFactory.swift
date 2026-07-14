import Foundation

// MARK: - AppContainer + Library Factory

/// Composition root for the Library feature.
/// Library receives the shared aggregation policy and FX provider explicitly.
extension AppContainer {
    func makeLibraryViewModel() -> LibraryViewModel {
        LibraryViewModel(
            repositories: repositories,
            preferences: preferences,
            notificationScheduler: notificationScheduler,
            exchangeRateProvider: exchangeRateProvider,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase()
        )
    }
}
