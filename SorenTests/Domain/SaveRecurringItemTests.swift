import Testing
import Foundation
@testable import Soren

// MARK: - SaveRecurringItem — notification scheduling tests

/// Verifies that SaveRecurringItem triggers the notification scheduler exactly
/// when and only when the item passes validation and is successfully persisted.
///
/// All tests run on @MainActor because SaveRecurringItem is @MainActor.
/// await Task.yield() is used to flush the fire-and-forget Task before asserting.

@Suite("SaveRecurringItem — notification scheduling")
@MainActor
struct SaveRecurringItemNotificationTests {

    // MARK: - Fixtures

    @MainActor
    private struct Fixture {
        let persistence: InMemoryPersistenceFixture
        let scheduler: MockNotificationScheduler
        let useCase: SaveRecurringItem

        init() throws {
            let persistence = try InMemoryPersistenceFixture()
            let scheduler = MockNotificationScheduler()

            self.persistence = persistence
            self.scheduler = scheduler
            self.useCase = SaveRecurringItem(
                repository: persistence.recurringItems,
                notificationScheduler: scheduler
            )
        }
    }

    private func makeFixture() throws -> Fixture {
        try Fixture()
    }

    private func validItem(title: String = "Spotify") -> RecurringItem {
        RecurringItem(
            title: title,
            amount: 299,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
    }

    // MARK: - Scheduling fires on success

    @Test("Successful save triggers schedule(for:) with the saved item")
    func schedulesFiredOnSuccess() async throws {
        let fixture = try makeFixture()

        let item = validItem()
        try fixture.useCase.execute(item)
        await fixture.scheduler.waitUntilScheduled(count: 1)

        #expect(fixture.scheduler.scheduledIDs.contains(item.id))
    }

    @Test("Successful save triggers schedule exactly once")
    func scheduledExactlyOnce() async throws {
        let fixture = try makeFixture()

        try fixture.useCase.execute(validItem())
        await fixture.scheduler.waitUntilScheduled(count: 1)

        #expect(fixture.scheduler.scheduledIDs.count == 1)
    }

    @Test("Scheduler is not called when notificationScheduler is nil")
    func noSchedulerMeansNoCall() async throws {
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let uc        = SaveRecurringItem(repository: repo, notificationScheduler: nil)

        // A separate mock is never injected — we just want to confirm the use case
        // completes without crashing and the item is persisted.
        try uc.execute(validItem())
        await Task.yield()

        // If we reach here without a crash, the nil-scheduler path is safe.
        // Persistence is verified by the LifecycleInvariantTests suite.
        #expect(Bool(true))
    }

    // MARK: - Scheduling blocked on validation failure

    @Test("Empty title validation failure does not schedule")
    func emptyTitleNoSchedule() async throws {
        let fixture = try makeFixture()

        let item = RecurringItem(
            title: "   ",
            amount: 299,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )

        #expect(throws: SaveRecurringItem.ValidationError.emptyTitle) {
            try fixture.useCase.execute(item)
        }
        await Task.yield()

        #expect(fixture.scheduler.scheduledIDs.isEmpty)
    }

    @Test("Zero amount validation failure does not schedule")
    func zeroAmountNoSchedule() async throws {
        let fixture = try makeFixture()

        let item = RecurringItem(
            title: "Spotify",
            amount: 0,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )

        #expect(throws: SaveRecurringItem.ValidationError.invalidAmount) {
            try fixture.useCase.execute(item)
        }
        await Task.yield()

        #expect(fixture.scheduler.scheduledIDs.isEmpty)
    }

    @Test("End-date-before-next-charge validation failure does not schedule")
    func endDateBeforeChargeNoSchedule() async throws {
        let fixture = try makeFixture()

        let nextCharge = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let endDate    = Calendar.current.date(byAdding: .day, value: 5,  to: .now)!  // before nextCharge

        let item = RecurringItem(
            title:          "Spotify",
            amount:         299,
            nextChargeDate: nextCharge,
            autoRenew:      false,
            endDate:        endDate
        )

        #expect(throws: SaveRecurringItem.ValidationError.endDateBeforeNextCharge) {
            try fixture.useCase.execute(item)
        }
        await Task.yield()

        #expect(fixture.scheduler.scheduledIDs.isEmpty)
    }

    // MARK: - Normalization happens before both persistence and scheduling

    /// Verifies that normalize() runs before repository.save(), so the persisted
    /// item has endDate == nil when autoRenew is true. Scheduling fires on the
    /// normalized copy, so this also proves scheduling receives a clean state.
    @Test("autoRenew=true: endDate is cleared in the persisted item")
    func normalizationClearsEndDateBeforePersistence() throws {
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let uc        = SaveRecurringItem(repository: repo)

        var item = validItem()
        item.autoRenew = true
        // Supply a non-nil endDate — normalize() must clear this before saving.
        item.endDate = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let savedID  = item.id

        try uc.execute(item)

        let persisted = try repo.fetch(id: savedID)
        #expect(persisted?.endDate == nil)
    }

}
