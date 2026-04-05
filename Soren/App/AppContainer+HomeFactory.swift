import Foundation

// MARK: - AppContainer + Home Factory

/// Composition root for the Home feature.
/// The only site in the app that wires HomeViewModel's explicit dependencies.
/// HomeViewModel itself has no knowledge of AppContainer or RepositoryContainer.
extension AppContainer {
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getUpcomingCharges: GetUpcomingCharges(repository: repositories.recurringItems),
            getActiveTrials: GetActiveTrials(repository: repositories.recurringItems),
            preferences: preferences
        )
    }
}
