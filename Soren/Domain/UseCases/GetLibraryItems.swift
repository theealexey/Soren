import Foundation

// MARK: - Use Case: Get Library Items

/// Fetches all recurring items for the Library screen.
/// Returns the complete collection; the caller applies current/archive scope.
@MainActor
struct GetLibraryItems {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    /// Returns all items. Caller applies search/filter/sort in the ViewModel.
    func execute() throws -> [RecurringItem] {
        try repository.fetchAll()
    }
}
