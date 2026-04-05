import Foundation

// MARK: - Use Case: Get Active Items

/// Fetches all active (non-archived, non-cancelled) recurring items.
/// Single-fetch entry point for screens that need the full active item list.
@MainActor
struct GetActiveItems {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute() throws -> [RecurringItem] {
        try repository.fetchActive()
    }
}
