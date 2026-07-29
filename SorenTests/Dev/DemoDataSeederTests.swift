#if DEBUG
import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Demo Data Seeder Tests

/// Adversarial coverage for DemoDataSeeder.
/// All tests run against an in-memory SwiftData store so they are
/// hermetic — no disk I/O, no shared state between test runs.
@Suite("DemoDataSeeder")
@MainActor
struct DemoDataSeederTests {

    // MARK: - Fixtures

    /// A fixed reference date (2026-06-15 local noon) used wherever
    /// deterministic date assertions are needed.
    private static let refDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 15; c.hour = 12
        return Calendar.current.date(from: c)!
    }()

    private static let cal = Calendar.current

    /// Retains the in-memory container for the full lifetime of each test.
    @MainActor
    private struct Fixture {
        let modelContainer: ModelContainer
        let repositories: RepositoryContainer
        let seeder: DemoDataSeeder

        var repo: any RecurringItemRepository {
            repositories.recurringItems
        }
    }

    private func makeFixture() throws -> Fixture {
        let modelContainer = try SorenModelContainer.inMemory()
        let repositories = RepositoryContainer(context: modelContainer.mainContext)
        return Fixture(
            modelContainer: modelContainer,
            repositories: repositories,
            seeder: DemoDataSeeder(
                repositories: repositories,
                preferences: UserPreferencesRepository()
            )
        )
    }

    // MARK: - Count

    @Test("seed() inserts exactly 15 items")
    func seedCreatesExpectedCount() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        #expect(try fixture.repo.fetchAll().count == 15)
    }

    // MARK: - Tag

    @Test("every seeded item carries the demo tag")
    func allSeededItemsHaveDemoTag() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let all = try fixture.repo.fetchAll()
        #expect(all.allSatisfy { $0.tags.contains(DemoDataSeeder.demoTag) })
    }

    // MARK: - Idempotency

    @Test("calling seed() twice still yields exactly 15 items")
    func seedIsIdempotent() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        try fixture.seeder.seed(relativeTo: Self.refDate)  // second call must be a no-op
        #expect(try fixture.repo.fetchAll().count == 15)
    }

    // MARK: - Clear

    @Test("clear() removes all demo-tagged items")
    func clearRemovesDemoItems() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        try fixture.seeder.clear()
        #expect(try fixture.repo.fetchAll().isEmpty)
    }

    @Test("clear() does not remove items without the demo tag")
    func clearDoesNotRemoveRealItems() throws {
        let fixture = try makeFixture()

        // Plant a real user item (no demo tag)
        let real = RecurringItem(
            title: "My Subscription",
            category: .other,
            amount: 9,
            currencyCode: "USD",
            billingCycle: .monthly,
            startDate: Self.refDate,
            nextChargeDate: Self.cal.date(byAdding: .month, value: 1, to: Self.refDate)!
        )
        try fixture.repo.save(real)

        try fixture.seeder.seed(relativeTo: Self.refDate)
        try fixture.seeder.clear()

        let remaining = try fixture.repo.fetchAll()
        #expect(remaining.count == 1)
        #expect(remaining.first?.title == "My Subscription")
    }

    // MARK: - isDemoDataPresent

    @Test("isDemoDataPresent is false before seeding")
    func isDemoDataPresentFalseInitially() throws {
        let fixture = try makeFixture()
        #expect(!fixture.seeder.isDemoDataPresent)
    }

    @Test("isDemoDataPresent is true after seeding")
    func isDemoDataPresentTrueAfterSeed() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        #expect(fixture.seeder.isDemoDataPresent)
    }

    @Test("isDemoDataPresent is false after seeding then clearing")
    func isDemoDataPresentFalseAfterClear() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        try fixture.seeder.clear()
        #expect(!fixture.seeder.isDemoDataPresent)
    }

    // MARK: - Relative Dates

    @Test("YouTube Premium nextChargeDate is exactly T+1 from reference date")
    func youTubeDateIsRelativeToReferenceDate() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)

        let all    = try fixture.repo.fetchAll()
        let item   = try #require(all.first { $0.providerID == "youtube_premium" })
        let today  = Self.cal.startOfDay(for: Self.refDate)
        let expected = Self.cal.date(byAdding: .day, value: 1, to: today)!
        #expect(item.nextChargeDate == expected)
    }

    @Test("X Premium nextChargeDate is in the past relative to reference date")
    func overdueDateIsBeforeReferenceDate() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)

        let all  = try fixture.repo.fetchAll()
        let item = try #require(all.first { $0.providerID == "x_premium" })
        #expect(item.nextChargeDate < Self.refDate)
    }

    @Test("Boosty nextChargeDate equals start of the reference day")
    func dueTodayDateEqualsStartOfReferenceDay() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)

        let all    = try fixture.repo.fetchAll()
        let item   = try #require(all.first { $0.providerID == "boosty" })
        let today  = Self.cal.startOfDay(for: Self.refDate)
        #expect(item.nextChargeDate == today)
    }

    @Test("NordVPN nextChargeDate falls in the calendar month after the reference date")
    func nordVpnChargeIsInNextMonth() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)

        let all  = try fixture.repo.fetchAll()
        let item = try #require(all.first { $0.providerID == "nordvpn" })
        let refMonth  = Self.cal.component(.month, from: Self.refDate)
        let itemMonth = Self.cal.component(.month, from: item.nextChargeDate)
        #expect(itemMonth == (refMonth % 12) + 1)
    }

    // MARK: - Special States

    @Test("X Premium has status .overdue")
    func xPremiumIsOverdue() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let item = try #require(try fixture.repo.fetchAll().first { $0.providerID == "x_premium" })
        #expect(item.status == .overdue)
    }

    @Test("Boosty has status .dueToday")
    func boostyIsDueToday() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let item = try #require(try fixture.repo.fetchAll().first { $0.providerID == "boosty" })
        #expect(item.status == .dueToday)
    }

    @Test("ChatGPT Plus has status .trial and a non-nil trialEndDate")
    func chatGptHasTrialEndDate() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let item = try #require(try fixture.repo.fetchAll().first { $0.providerID == "chatgpt_plus" })
        #expect(item.status == .trial)
        #expect(item.trialEndDate != nil)
    }

    @Test("Notion has usageStatus .unused")
    func notionIsUnused() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let item = try #require(try fixture.repo.fetchAll().first { $0.providerID == "notion" })
        #expect(item.usageStatus == .unused)
    }

    @Test("NordVPN has billingCycle .annual")
    func nordVpnIsAnnual() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let item = try #require(try fixture.repo.fetchAll().first { $0.providerID == "nordvpn" })
        #expect(item.billingCycle == .annual)
    }

    // MARK: - Currency Mix

    @Test("dataset contains at least one item for each of RUB, USD, EUR, TRY")
    func datasetHasMixedCurrencies() throws {
        let fixture = try makeFixture()
        try fixture.seeder.seed(relativeTo: Self.refDate)
        let currencies = Set(try fixture.repo.fetchAll().map(\.currencyCode))
        #expect(currencies.contains("RUB"))
        #expect(currencies.contains("USD"))
        #expect(currencies.contains("EUR"))
        #expect(currencies.contains("TRY"))
    }
}
#endif
