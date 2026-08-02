import Foundation

// MARK: - Use Case: Delete Recurring Item

/// Permanently removes a recurring item, then reconciles the full desired
/// notification state from persistence.
@MainActor
struct DeleteRecurringItem {

    private let repository: any RecurringItemRepository
    private let notificationCoordinator: (any NotificationStateReconciling)?

    init(
        repository: any RecurringItemRepository,
        notificationCoordinator: (any NotificationStateReconciling)? = nil
    ) {
        self.repository = repository
        self.notificationCoordinator = notificationCoordinator
    }

    @discardableResult
    func execute(id: UUID) async throws -> NotificationRefreshOutcome? {
        try repository.delete(id: id)
        return await notificationCoordinator?.reconcileCurrentState(source: .delete)
    }
}
