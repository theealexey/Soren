import Foundation

// MARK: - Use Case: Get Active Trials

/// Fetches items that are in trial status and trial hasn't expired.
/// Critical for Home "trials ending soon" section.
@MainActor
struct GetActiveTrials {

    private let repository: SwiftDataRecurringItemRepository

    init(repository: SwiftDataRecurringItemRepository) {
        self.repository = repository
    }

    func execute() throws -> [RecurringItem] {
        try repository.fetchActive().filter { $0.isActiveTrial }
    }
}
