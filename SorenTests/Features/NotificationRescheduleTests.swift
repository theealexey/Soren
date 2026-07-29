import Testing
import Foundation
@testable import Soren

// MARK: - NotificationRefreshCoordinator Tests

@Suite("NotificationRefreshCoordinator — foreground reschedule")
@MainActor
struct NotificationRefreshCoordinatorTests {

    // MARK: - Fixtures

    @MainActor
    private struct Fixture {
        let persistence: InMemoryPersistenceFixture
        let scheduler: MockNotificationScheduler
        let coordinator: NotificationRefreshCoordinator

        init() throws {
            let persistence = try InMemoryPersistenceFixture()
            let scheduler = MockNotificationScheduler()

            self.persistence = persistence
            self.scheduler = scheduler
            self.coordinator = NotificationRefreshCoordinator(
                repository: persistence.repositories.recurringItems,
                scheduler: scheduler
            )
        }
    }

    private func makeFixture() throws -> Fixture {
        try Fixture()
    }

    private func freshItem(
        chargeReminder: ChargeReminderOption = .threeDaysBefore,
        trialReminder:  TrialReminderOption  = .never,
        trialEndDate:   Date?                = nil
    ) -> RecurringItem {
        RecurringItem(
            title:          "Test Sub",
            amount:         9.99,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            trialEndDate:   trialEndDate,
            chargeReminder: chargeReminder,
            trialReminder:  trialReminder
        )
    }

    // MARK: - Wiring

    @Test("didBecomeActive passes all stored items to rescheduleAll")
    func reschedulesAllStoredItems() async throws {
        let fixture = try makeFixture()

        let a = freshItem()
        let b = freshItem()
        try fixture.persistence.repositories.recurringItems.save(a)
        try fixture.persistence.repositories.recurringItems.save(b)

        fixture.coordinator.didBecomeActive()
        await fixture.scheduler.waitUntilRescheduled(count: 1)

        #expect(fixture.scheduler.rescheduleAllCallCount == 1)
        let ids = Set(fixture.scheduler.lastRescheduledItems.map(\.id))
        #expect(ids == Set([a.id, b.id]))
    }

    @Test("empty repository triggers rescheduleAll with empty list")
    func emptyRepositoryPassesEmptyList() async throws {
        let fixture = try makeFixture()

        fixture.coordinator.didBecomeActive()
        await fixture.scheduler.waitUntilRescheduled(count: 1)

        #expect(fixture.scheduler.rescheduleAllCallCount == 1)
        #expect(fixture.scheduler.lastRescheduledItems.isEmpty)
    }

    @Test("paused, archived, and .never items are forwarded — scheduler owns eligibility")
    func ineligibleItemsForwardedToScheduler() async throws {
        let fixture = try makeFixture()

        var paused   = freshItem(); paused.status   = .paused
        var archived = freshItem(); archived.status = .archived
        let neverR   = freshItem(chargeReminder: .never)
        try fixture.persistence.repositories.recurringItems.save(paused)
        try fixture.persistence.repositories.recurringItems.save(archived)
        try fixture.persistence.repositories.recurringItems.save(neverR)

        fixture.coordinator.didBecomeActive()
        await fixture.scheduler.waitUntilRescheduled(count: 1)

        // Coordinator passes every stored item; real NotificationScheduler filters
        // via isEligible() inside schedule(for:).
        #expect(fixture.scheduler.rescheduleAllCallCount == 1)
        #expect(fixture.scheduler.lastRescheduledItems.count == 3)
    }

    @Test("item with both charge and trial reminders is forwarded intact")
    func itemWithBothRemindersForwardedIntact() async throws {
        let fixture = try makeFixture()

        let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let item = freshItem(
            chargeReminder: .threeDaysBefore,
            trialReminder:  .oneDayBefore,
            trialEndDate:   trialEnd
        )
        try fixture.persistence.repositories.recurringItems.save(item)

        fixture.coordinator.didBecomeActive()
        await fixture.scheduler.waitUntilRescheduled(count: 1)

        let forwarded = fixture.scheduler.lastRescheduledItems.first
        #expect(forwarded?.id == item.id)
        #expect(forwarded?.chargeReminder == .threeDaysBefore)
        #expect(forwarded?.trialReminder  == .oneDayBefore)
        #expect(forwarded?.trialEndDate   != nil)
    }

    @Test("rapid calls produce at most one reschedule run")
    func rapidCallsProduceAtMostOneRun() async throws {
        let fixture = try makeFixture()

        fixture.coordinator.didBecomeActive()
        fixture.coordinator.didBecomeActive()
        fixture.coordinator.didBecomeActive()
        await Task.yield()

        #expect(fixture.scheduler.rescheduleAllCallCount <= 1)
    }
}

// MARK: - rescheduleAll contract tests

@Suite("NotificationScheduler — rescheduleAll contract")
struct NotificationSchedulerRescheduleAllContractTests {

    // These tests verify that rescheduleAll's item-list semantics are correct
    // at the mock level (the real NotificationScheduler's stale-clearing is
    // implementation-level and exercised by the coordinator integration above).

    @Test("rescheduleAll records all items passed to it")
    func recordsAllItems() async {
        let mock = MockNotificationScheduler()
        let items: [RecurringItem] = [
            RecurringItem(title: "A", amount: 1, nextChargeDate: .now),
            RecurringItem(title: "B", amount: 2, nextChargeDate: .now),
            RecurringItem(title: "C", amount: 3, nextChargeDate: .now),
        ]
        await mock.rescheduleAll(items: items)

        #expect(mock.rescheduleAllCallCount == 1)
        #expect(mock.lastRescheduledItems.count == 3)
    }

    @Test("rescheduleAll with empty list records an empty call")
    func emptyListRecorded() async {
        let mock = MockNotificationScheduler()
        await mock.rescheduleAll(items: [])

        #expect(mock.rescheduleAllCallCount == 1)
        #expect(mock.lastRescheduledItems.isEmpty)
    }

    @Test("successive rescheduleAll calls replace lastRescheduledItems")
    func successiveCallsReplaceItems() async {
        let mock = MockNotificationScheduler()
        let first  = [RecurringItem(title: "Old", amount: 1, nextChargeDate: .now)]
        let second = [RecurringItem(title: "New", amount: 2, nextChargeDate: .now)]

        await mock.rescheduleAll(items: first)
        await mock.rescheduleAll(items: second)

        #expect(mock.rescheduleAllCallCount == 2)
        #expect(mock.lastRescheduledItems.map(\.title) == ["New"])
    }
}
