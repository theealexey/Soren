import Foundation

// MARK: - Use Case: Delete Recurring Item

/// Permanently removes a recurring item from persistence and cancels its
/// pending notification as a deterministic side effect.
@MainActor
struct DeleteRecurringItem {

    private let repository: any RecurringItemRepository
    private let notificationScheduler: (any NotificationScheduling)?

    init(
        repository: any RecurringItemRepository,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    func execute(id: UUID) async throws {
        try repository.delete(id: id)
        if let scheduler = notificationScheduler {
            await scheduler.cancel(for: id)
        }
    }
}
