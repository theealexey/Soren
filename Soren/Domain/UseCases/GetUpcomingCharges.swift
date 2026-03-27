import Foundation

// MARK: - Use Case: Get Upcoming Charges

/// Fetches items charging within a given time window.
/// Used by Home (next 7 days) and Calendar (configurable window).
@MainActor
struct GetUpcomingCharges {

    private let repository: SwiftDataRecurringItemRepository

    init(repository: SwiftDataRecurringItemRepository) {
        self.repository = repository
    }

    /// Returns items with nextChargeDate within `days` from `referenceDate`.
    func execute(days: Int = 7, from referenceDate: Date = .now) throws -> [RecurringItem] {
        try repository.fetchUpcoming(within: days, from: referenceDate)
    }
}
