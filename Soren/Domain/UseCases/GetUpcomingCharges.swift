import Foundation

// MARK: - Use Case: Get Upcoming Charges

/// Fetches items charging within a given time window.
/// Used by Home (next 7 days) and Calendar (configurable window).
@MainActor
struct GetUpcomingCharges {

    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    /// Returns items whose effective upcoming charge date falls within `days` from `referenceDate`.
    ///
    /// Combines two passes:
    ///   1. Items whose stored `nextChargeDate` is already in the window (fast DB query).
    ///   2. Items whose stored `nextChargeDate` is in the past but whose display-layer
    ///      `effectiveNextChargeDate` rolls forward into the window — so overdue-but-still-active
    ///      recurring subscriptions appear in the correct upcoming day bucket.
    ///
    /// No persisted dates are mutated. Sorting uses the effective date so rolled items
    /// interleave correctly with natively-scheduled ones.
    func execute(days: Int = 7, from referenceDate: Date = .now) throws -> [RecurringItem] {
        let cal    = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: days, to: referenceDate) ?? referenceDate

        let inWindow    = try repository.fetchUpcoming(within: days, from: referenceDate)
        let inWindowIDs = Set(inWindow.map(\.id))

        let rolled: [RecurringItem] = try repository.fetchAll()
            .filter { !inWindowIDs.contains($0.id) && $0.nextChargeDate < referenceDate }
            .filter { item in
                let effective = item.effectiveNextChargeDate(relativeTo: referenceDate, calendar: cal)
                return effective >= referenceDate && effective <= cutoff
            }

        return (inWindow + rolled).sorted {
            $0.effectiveNextChargeDate(relativeTo: referenceDate, calendar: cal)
                < $1.effectiveNextChargeDate(relativeTo: referenceDate, calendar: cal)
        }
    }
}
