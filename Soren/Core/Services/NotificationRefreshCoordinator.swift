import Foundation

// MARK: - Notification Refresh Coordinator

/// Fetches the current set of recurring items and calls
/// `NotificationScheduling.rescheduleAll(items:)` when the app foregrounds.
///
/// Owned by `AppContainer`; triggered from `scenePhase` observation in `SorenApp`.
///
/// Storing a cancellable Task handle ensures that rapid foreground activations
/// — e.g. iPad Split View bringing multiple windows active, or Mac window cycling —
/// never produce overlapping reschedule runs. Only the most recent activation wins.
@MainActor
final class NotificationRefreshCoordinator {

    // MARK: - Dependencies

    private let repository: any RecurringItemRepository
    private let scheduler: any NotificationScheduling
    private var refreshTask: Task<Void, Never>?

    // MARK: - Init

    init(
        repository: any RecurringItemRepository,
        scheduler: any NotificationScheduling
    ) {
        self.repository = repository
        self.scheduler = scheduler
    }

    // MARK: - Activation

    /// Called when the app scene transitions to `.active`.
    /// Cancels any in-flight reschedule before starting a fresh one.
    func didBecomeActive() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            guard let items = try? repository.fetchAll() else { return }
            await scheduler.rescheduleAll(items: items)
        }
    }
}
