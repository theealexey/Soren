import Foundation

// MARK: - Use Case: Delete Recurring Item

/// Permanently removes a recurring item from persistence.
@MainActor
struct DeleteRecurringItem {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute(id: UUID) throws {
        try repository.delete(id: id)
    }
}
