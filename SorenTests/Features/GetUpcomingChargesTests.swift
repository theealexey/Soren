import Foundation
import Testing
@testable import Soren

@Suite("GetUpcomingCharges canonical schedule")
@MainActor
struct GetUpcomingChargesUseCaseTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }

    /// Persisted billing fixtures use the Domain representation, not the supplied
    /// projector calendar's local-midnight carrier.
    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try BillingCivilDay.canonicalDate(for: CivilDate(year: year, month: month, day: day))
    }

    /// The projector's explicit Calendar determines occurrence carriers. Compare
    /// their civil days with canonical billing expectations without changing that
    /// Calendar dependency or asserting a local instant as storage representation.
    private func occurrenceDays(
        _ occurrences: [UpcomingScheduledCharge],
        calendar: Calendar? = nil
    ) throws -> [Date] {
        let timeZone = (calendar ?? self.calendar).timeZone
        return try occurrences.map {
            try BillingCivilDay.canonicalDate(for: BillingCivilDay.civilDate(containing: $0.date, in: timeZone))
        }
    }

    private func item(
        id: UUID = UUID(),
        next: Date,
        start: Date,
        cycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        autoRenew: Bool = true,
        end: Date? = nil,
        trialEnd: Date? = nil,
        archivedAt: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            id: id,
            title: "Subscription",
            amount: 100,
            billingCycle: cycle,
            startDate: start,
            nextChargeDate: next,
            trialEndDate: trialEnd,
            autoRenew: autoRenew,
            endDate: end,
            status: status,
            archivedAt: archivedAt
        )
    }

    private func fixture() throws -> InMemoryPersistenceFixture {
        try InMemoryPersistenceFixture()
    }

    @Test("Nearest three are sorted by date then UUID and later rows are omitted")
    func nearestThree() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        let earlierID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let laterID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let items = [
            item(id: laterID, next: try date(2026, 8, 20), start: today, cycle: .annual),
            item(next: try date(2026, 9, 1), start: today, cycle: .annual),
            item(id: earlierID, next: try date(2026, 8, 20), start: today, cycle: .annual),
            item(next: try date(2026, 8, 15), start: today, cycle: .annual),
        ]
        try fixture.recurringItems.saveAll(items)

        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(result.count == 3)
        #expect(try occurrenceDays(result) == [
            try date(2026, 8, 15), try date(2026, 8, 20), try date(2026, 8, 20)
        ])
        #expect(result[1].item.id == earlierID)
        #expect(result[2].item.id == laterID)
    }

    @Test("Weekly schedule retains multiple occurrences of the same item")
    func weeklyMultiplicity() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        let weekly = item(next: try date(2026, 8, 1), start: try date(2026, 1, 1), cycle: .weekly)
        try fixture.recurringItems.save(weekly)

        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(result.map(\.item.id) == [weekly.id, weekly.id, weekly.id])
        #expect(try occurrenceDays(result) == [
            try date(2026, 8, 15), try date(2026, 8, 22), try date(2026, 8, 29)
        ])
    }

    @Test("End-of-month recurrence uses the unchanged canonical anchor")
    func monthEndAnchor() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 1)
        try fixture.recurringItems.save(item(
            next: try date(2026, 7, 31), start: try date(2026, 1, 1)
        ))
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(try occurrenceDays(result) == [
            try date(2026, 8, 31), try date(2026, 9, 30), try date(2026, 10, 31)
        ])
    }

    @Test("Trial boundary alone is not a monetary Upcoming charge")
    func trialBoundaryAlone() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        try fixture.recurringItems.save(item(
            next: try date(2026, 8, 25), start: today,
            status: .trial, trialEnd: try date(2026, 8, 20)
        ))
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test("Proven trial renewal is a monetary Upcoming occurrence")
    func provenTrialRenewal() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        let renewal = try date(2026, 8, 20)
        try fixture.recurringItems.save(item(
            next: renewal, start: today, status: .trial, trialEnd: renewal
        ))
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(try occurrenceDays(result).first == renewal)
    }

    @Test("Finite end date is inclusive and excludes following occurrences")
    func finiteEndDate() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        try fixture.recurringItems.save(item(
            next: try date(2026, 8, 14), start: today,
            cycle: .weekly, autoRenew: false, end: try date(2026, 8, 21)
        ))
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(try occurrenceDays(result) == [try date(2026, 8, 14), try date(2026, 8, 21)])
    }

    @Test("Paused cancelled and archived items are excluded by projector")
    func inactiveItems() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        let next = try date(2026, 8, 14)
        try fixture.recurringItems.saveAll([
            item(next: next, start: today, status: .paused),
            item(next: next, start: today, status: .cancelled),
            item(next: next, start: today, archivedAt: today),
        ])
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test("Overdue and failed lifecycle statuses retain valid schedule occurrences")
    func eligibleAttentionStatuses() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        let next = try date(2026, 8, 14)
        try fixture.recurringItems.saveAll([
            item(next: next, start: today, status: .overdue),
            item(next: next, start: today, status: .failed),
        ])
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.item.status == .overdue || $0.item.status == .failed })
    }

    @Test("One-year horizon includes anniversary day but not later annual renewal")
    func oneYearHorizon() throws {
        let fixture = try fixture()
        let today = try date(2026, 8, 13)
        try fixture.recurringItems.saveAll([
            item(next: try date(2027, 8, 13), start: try date(2027, 8, 13), cycle: .annual),
            item(next: try date(2027, 8, 14), start: try date(2027, 8, 14), cycle: .annual),
        ])
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: calendar)
        #expect(try occurrenceDays(result) == [try date(2027, 8, 13)])
    }

    @Test("Supplied Gregorian calendar and timezone determine civil schedule days")
    func suppliedCalendar() throws {
        let fixture = try fixture()
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let today = try date(2026, 9, 1)
        try fixture.recurringItems.save(item(next: today, start: today, cycle: .annual))
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: today, calendar: tokyo)
        #expect(try occurrenceDays(result, calendar: tokyo) == [
            today,
            try date(2027, 9, 1),
        ])
    }

    @Test("Empty repository produces fewer than three without placeholders")
    func empty() throws {
        let fixture = try fixture()
        let result = try GetUpcomingCharges(repository: fixture.recurringItems)
            .execute(from: date(2026, 8, 13), calendar: calendar)
        #expect(result.isEmpty)
    }

    @Test("Repository failure is propagated instead of becoming empty Upcoming")
    func repositoryFailure() throws {
        let today = try date(2026, 8, 13)
        #expect(throws: FetchFailure.unavailable) {
            try GetUpcomingCharges(repository: FailingRepository())
                .execute(from: today, calendar: calendar)
        }
    }
}

private enum FetchFailure: Error, Equatable {
    case unavailable
}

@MainActor
private final class FailingRepository: RecurringItemRepository {
    func fetchAll() throws -> [RecurringItem] { throw FetchFailure.unavailable }
    func fetchActive() throws -> [RecurringItem] { [] }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { [] }
    func fetch(id: UUID) throws -> RecurringItem? { nil }
    func save(_ item: RecurringItem) throws {}
    func update(_ item: RecurringItem) throws {}
    func delete(id: UUID) throws {}
    func saveAll(_ items: [RecurringItem]) throws {}
    func deleteAll() throws {}
}
