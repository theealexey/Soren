import Testing
import Foundation
@testable import Soren

// MARK: - GetUpcomingCharges Tests

/// Adversarial tests for GetUpcomingCharges.execute().
///
/// Coverage targets:
///   • Pass-1 (in-window stored dates)
///   • Pass-2 (rolled effective dates)
///   • Non-rolling status guards (.paused / .cancelled / .archived)
///   • Non-autoRenew guard (finite subscriptions never roll)
///   • Sort correctness — results ordered by effective date, not stored date
///   • Boundary — item whose effective date rolls past the cutoff is excluded
///   • Rolling-eligible but attention-requiring statuses (.overdue, .failed) are included
///   • Empty repository produces an empty result

@Suite("GetUpcomingCharges — rolling & sort")
@MainActor
struct GetUpcomingChargesUseCaseTests {

    // MARK: - Fixtures

    private let cal = Calendar.current

    /// Stable "today" anchor — start of the current day so all comparisons
    /// are against midnight boundaries regardless of test execution time.
    private var today: Date { cal.startOfDay(for: .now) }

    private func makeUseCase() throws -> (GetUpcomingCharges, any RecurringItemRepository) {
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        return (GetUpcomingCharges(repository: repo), repo)
    }

    private func makeItem(
        title:        String      = "Test",
        nextCharge:   Date,
        billingCycle: BillingCycle = .monthly,
        status:       ItemStatus   = .active,
        autoRenew:    Bool         = true,
        archivedAt:   Date?        = nil
    ) -> RecurringItem {
        RecurringItem(
            title:         title,
            amount:        9.99,
            billingCycle:  billingCycle,
            nextChargeDate: nextCharge,
            autoRenew:     autoRenew,
            status:        status,
            archivedAt:    archivedAt
        )
    }

    // MARK: - Pass 1: stored date in window

    @Test("Item with stored date inside window is included")
    func storedInWindowIncluded() throws {
        let (uc, repo) = try makeUseCase()
        let item = makeItem(nextCharge: cal.date(byAdding: .day, value: 3, to: today)!)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(ids.contains(item.id))
    }

    @Test("Item with stored date exactly at the cutoff boundary is included")
    func storedAtCutoffIncluded() throws {
        let (uc, repo) = try makeUseCase()
        let item = makeItem(nextCharge: cal.date(byAdding: .day, value: 7, to: today)!)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(ids.contains(item.id))
    }

    // MARK: - Pass 2: rolled effective dates

    @Test("Active autoRenew item with stale date that rolls into window is included")
    func staleActiveRolledIn() throws {
        let (uc, repo) = try makeUseCase()
        // Stored 3 days ago, 7-day cycle → effective = today + 4 days (within 7-day window).
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .weekly, status: .active)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(ids.contains(item.id))
    }

    @Test("Overdue item (rolling-eligible) with stale date that rolls into window is included")
    func overdueRolledIn() throws {
        let (uc, repo) = try makeUseCase()
        // .overdue is rolling-eligible — it must NOT be caught by the status guard.
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .weekly, status: .overdue)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(ids.contains(item.id))
    }

    @Test("Failed item (rolling-eligible) with stale date that rolls into window is included")
    func failedRolledIn() throws {
        let (uc, repo) = try makeUseCase()
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .weekly, status: .failed)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(ids.contains(item.id))
    }

    @Test("Stale item whose effective date rolls past the cutoff is excluded")
    func stalePastCutoffExcluded() throws {
        let (uc, repo) = try makeUseCase()
        // Stored 10 days ago, 9-day custom cycle:
        //   iter 1: -10 + 9 = -1 day (still < today)
        //   iter 2: -1 + 9  = +8 days → effective = today + 8 > cutoff (7 days)
        let stale = cal.date(byAdding: .day, value: -10, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .custom(days: 9), status: .active)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(!ids.contains(item.id))
    }

    // MARK: - Non-rolling status guards

    @Test("Paused item with stale date is excluded from rolled pass")
    func pausedExcluded() throws {
        let (uc, repo) = try makeUseCase()
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .weekly, status: .paused)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(!ids.contains(item.id))
    }

    @Test("Cancelled item with stale date is excluded from rolled pass")
    func cancelledExcluded() throws {
        let (uc, repo) = try makeUseCase()
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(nextCharge: stale, billingCycle: .weekly, status: .cancelled)
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(!ids.contains(item.id))
    }

    @Test("Archived item does not appear in either pass")
    func archivedExcluded() throws {
        let (uc, repo) = try makeUseCase()
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        // archivedAt set so fetchUpcoming's `archivedAt == nil` predicate excludes it from pass 1;
        // status guard excludes it from pass 2.
        let item  = makeItem(
            nextCharge: stale,
            billingCycle: .weekly,
            status: .archived,
            archivedAt: today
        )
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(!ids.contains(item.id))
    }

    // MARK: - autoRenew guard

    @Test("Non-autoRenew item with stale date is not rolled into the window")
    func nonAutoRenewNotRolled() throws {
        let (uc, repo) = try makeUseCase()
        let stale = cal.date(byAdding: .day, value: -3, to: today)!
        let item  = makeItem(
            nextCharge: stale,
            billingCycle: .weekly,
            status: .active,
            autoRenew: false
        )
        try repo.save(item)

        let ids = try uc.execute(days: 7, from: today).map(\.id)
        #expect(!ids.contains(item.id))
    }

    // MARK: - Sort correctness

    @Test("Results are sorted by effective date, not stored date")
    func sortedByEffectiveDate() throws {
        let (uc, repo) = try makeUseCase()

        // A: stored date 5 days from now → effective = +5 days.
        let a = makeItem(title: "A", nextCharge: cal.date(byAdding: .day, value: 5, to: today)!)
        // B: stored 3 days ago, weekly (7-day) cycle → effective = today + 4 days.
        //    effectiveDate(+4) < A(+5) so B should sort before A.
        let bStale = cal.date(byAdding: .day, value: -3, to: today)!
        let b = makeItem(title: "B", nextCharge: bStale, billingCycle: .weekly)
        // C: stored date 6 days from now → effective = +6 days.
        let c = makeItem(title: "C", nextCharge: cal.date(byAdding: .day, value: 6, to: today)!)

        try repo.save(a)
        try repo.save(b)
        try repo.save(c)

        let titles = try uc.execute(days: 7, from: today).map(\.title)

        // B (eff +4) < A (eff +5) < C (eff +6)
        let bIdx = try #require(titles.firstIndex(of: "B"))
        let aIdx = try #require(titles.firstIndex(of: "A"))
        let cIdx = try #require(titles.firstIndex(of: "C"))
        #expect(bIdx < aIdx)
        #expect(aIdx < cIdx)
    }

    // MARK: - No duplication

    @Test("Item with stored date in window appears exactly once (not duplicated by pass 2)")
    func noduplication() throws {
        let (uc, repo) = try makeUseCase()
        let item = makeItem(nextCharge: cal.date(byAdding: .day, value: 2, to: today)!)
        try repo.save(item)

        let results = try uc.execute(days: 7, from: today)
        let matchCount = results.filter { $0.id == item.id }.count
        #expect(matchCount == 1)
    }

    // MARK: - Empty repository

    @Test("Empty repository returns empty result")
    func emptyRepo() throws {
        let (uc, _) = try makeUseCase()
        let results = try uc.execute(days: 7, from: today)
        #expect(results.isEmpty)
    }
}
