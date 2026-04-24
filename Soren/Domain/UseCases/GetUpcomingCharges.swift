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
    ///
    /// Performance: `effectiveNextChargeDate` is called exactly once per item.
    /// Tags `(item, effectiveDate)` pairs are computed up-front; the sort reuses those
    /// cached dates rather than recomputing them O(n log n × 2) times.
    func execute(days: Int = 7, from referenceDate: Date = .now) throws -> [RecurringItem] {
        let cal    = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: days, to: referenceDate) ?? referenceDate

        // Pass 1: items whose stored nextChargeDate is already in the window (fast DB query).
        // Tag each with its effective date — computed once here and reused in the sort.
        let inWindow    = try repository.fetchUpcoming(within: days, from: referenceDate)
        let inWindowIDs = Set(inWindow.map(\.id))
        let inWindowTagged: [(RecurringItem, Date)] = inWindow.map {
            ($0, $0.effectiveNextChargeDate(relativeTo: referenceDate, calendar: cal))
        }

        // Pass 2: items whose stored date is in the past but whose effective date rolls into
        // the window (overdue-but-still-active recurring subscriptions).
        //
        // Guards are ordered cheapest-to-most-expensive:
        //   1. Already captured by pass 1 — skip.
        //   2. Stored date not yet past — the window case is entirely handled by pass 1.
        //   3. Finite subscriptions (autoRenew == false) never roll forward — skip before
        //      the while-loop inside effectiveNextChargeDate.
        //   4. Non-rolling statuses (.paused/.cancelled/.archived) return the stored date
        //      unchanged, so their stale stored date can never reach a future window — skip.
        //   5. Compute effectiveNextChargeDate exactly once and verify window membership.
        let rolledTagged: [(RecurringItem, Date)] = try repository.fetchAll()
            .compactMap { item -> (RecurringItem, Date)? in
                guard !inWindowIDs.contains(item.id) else { return nil }
                guard item.nextChargeDate < referenceDate  else { return nil }
                guard item.autoRenew                       else { return nil }
                switch item.status {
                case .paused, .cancelled, .archived:       return nil
                default:                                   break
                }
                let effective = item.effectiveNextChargeDate(relativeTo: referenceDate, calendar: cal)
                guard effective >= referenceDate, effective <= cutoff else { return nil }
                return (item, effective)
            }

        // Sort using pre-computed effective dates — no further effectiveNextChargeDate calls.
        return (inWindowTagged + rolledTagged)
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
