import Testing
import Foundation
@testable import Soren

// MARK: - UpdateRecurringItem — notification scheduling tests

/// Verifies that UpdateRecurringItem calls the notification scheduler
/// when and only when the item is successfully persisted.
///
/// execute(_:) is async throws and directly awaits scheduler.schedule(for:),
/// so assertions are deterministic — no Task.yield or scheduling tricks needed.
///
/// The mock scheduler records every schedule() call without any eligibility
/// filtering. The real NotificationScheduler handles that internally:
/// it calls cancel(for:) when the item is paused, archived, or has reminder=.never.
/// These tests verify the call is made; integration tests cover the real scheduler's
/// eligibility logic separately.

@Suite("UpdateRecurringItem — notification scheduling")
@MainActor
struct UpdateRecurringItemSchedulingTests {

    // MARK: - Helpers

    private func activeItem() -> RecurringItem {
        RecurringItem(
            title:          "Spotify",
            amount:         299,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        )
    }

    // MARK: - Scheduler fires on success

    @Test("Scheduler is called after a successful update")
    func schedulerCalledAfterSuccessfulUpdate() async throws {
        let mock      = MockNotificationScheduler()
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let item      = activeItem()
        try repo.save(item)

        let uc = UpdateRecurringItem(repository: repo, notificationScheduler: mock)
        try await uc.execute(item)

        #expect(mock.scheduledIDs.contains(item.id))
    }

    @Test("Scheduler is called exactly once per successful update")
    func schedulerCalledExactlyOnce() async throws {
        let mock      = MockNotificationScheduler()
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let item      = activeItem()
        try repo.save(item)

        let uc = UpdateRecurringItem(repository: repo, notificationScheduler: mock)
        try await uc.execute(item)

        #expect(mock.scheduledIDs.count == 1)
    }

    // MARK: - Scheduler not called on validation failure

    @Test("Validation failure does not trigger the scheduler")
    func validationFailureDoesNotSchedule() async throws {
        let mock = MockNotificationScheduler()
        var badItem = activeItem()
        badItem.title = "  "   // will fail emptyTitle validation

        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let uc        = UpdateRecurringItem(repository: repo, notificationScheduler: mock)

        await #expect(throws: UpdateRecurringItem.ValidationError.emptyTitle) {
            try await uc.execute(badItem)
        }

        #expect(mock.scheduledIDs.isEmpty)
    }

    // MARK: - Scheduler called for ineligible items (mock records; real scheduler cancels)

    @Test("Paused item update calls schedule(for:) — real scheduler cancels internally")
    func pausedItemCallsSchedule() async throws {
        let mock      = MockNotificationScheduler()
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        var item      = activeItem()
        item.status   = .paused
        try repo.save(item)

        let uc = UpdateRecurringItem(repository: repo, notificationScheduler: mock)
        try await uc.execute(item)

        #expect(mock.scheduledIDs.contains(item.id))
    }

    @Test("Archived item update calls schedule(for:) — real scheduler cancels internally")
    func archivedItemCallsSchedule() async throws {
        let mock      = MockNotificationScheduler()
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        var item      = activeItem()
        item.status   = .archived
        try repo.save(item)

        let uc = UpdateRecurringItem(repository: repo, notificationScheduler: mock)
        try await uc.execute(item)

        #expect(mock.scheduledIDs.contains(item.id))
    }

    // MARK: - Nil scheduler

    @Test("Nil scheduler completes without crash")
    func nilSchedulerDoesNotCrash() async throws {
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let item      = activeItem()
        try repo.save(item)

        let uc     = UpdateRecurringItem(repository: repo, notificationScheduler: nil)
        let result = try await uc.execute(item)

        #expect(result.id == item.id)
    }
}
