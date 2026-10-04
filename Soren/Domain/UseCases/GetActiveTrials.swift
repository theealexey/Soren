import Foundation

// MARK: - Use Case: Get Active Trials

/// Fetches items that are in trial status and trial hasn't expired.
/// Critical for Home "trials ending soon" section.
@MainActor
struct GetActiveTrials {

    private let repository: any RecurringItemRepository
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    init(repository: any RecurringItemRepository, now: @escaping () -> Date = { .now }, timeZone: @escaping () -> TimeZone = { .current }) {
        self.repository = repository
        self.now = now
        self.timeZone = timeZone
    }

    func execute() throws -> [RecurringItem] {
        let today = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
        return try repository.fetchActive().filter { try $0.isActiveTrial(on: today) }
    }
}
