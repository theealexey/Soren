import Foundation

// MARK: - Use Case: Get Library Items

/// Fetches all recurring items for the Library screen.
/// Returns unarchived items by default; archived items on request.
@MainActor
struct GetLibraryItems {

    private let repository: SwiftDataRecurringItemRepository

    init(repository: SwiftDataRecurringItemRepository) {
        self.repository = repository
    }

    /// Returns all items. Caller applies search/filter/sort in the ViewModel.
    func execute() throws -> [RecurringItem] {
        try repository.fetchAll()
    }
}
