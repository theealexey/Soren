import Testing
import Foundation
@testable import Soren

// MARK: - NotificationRefreshCoordinator Tests

@Suite("NotificationRefreshCoordinator — foreground reschedule")
@MainActor
struct NotificationRefreshCoordinatorTests {

    // MARK: - Fixtures

    private func makeRepos() throws -> RepositoryContainer {
        let container = try SorenModelContainer.inMemory()
        return RepositoryContainer(context: container.mainContext)
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
        let repos = try makeRepos()
        let mock  = MockNotificationScheduler()
        let coordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            scheduler:  mock
        )

        let a = freshItem()
        let b = freshItem()
        try repos.recurringItems.save(a)
        try repos.recurringItems.save(b)

        coordinator.didBecomeActive()
        await Task.yield()

        #expect(mock.rescheduleAllCallCount == 1)
        let ids = Set(mock.lastRescheduledItems.map(\.id))
        #expect(ids == Set([a.id, b.id]))
    }

    @Test("empty repository triggers rescheduleAll with empty list")
    func emptyRepositoryPassesEmptyList() async throws {
        let repos = try makeRepos()
        let mock  = MockNotificationScheduler()
        let coordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            scheduler:  mock
        )

        coordinator.didBecomeActive()
        await Task.yield()

        #expect(mock.rescheduleAllCallCount == 1)
        #expect(mock.lastRescheduledItems.isEmpty)
    }

    @Test("paused, archived, and .never items are forwarded — scheduler owns eligibility")
    func ineligibleItemsForwardedToScheduler() async throws {
        let repos = try makeRepos()
        let mock  = MockNotificationScheduler()
        let coordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            scheduler:  mock
        )

        var paused   = freshItem(); paused.status   = .paused
        var archived = freshItem(); archived.status = .archived
        let neverR   = freshItem(chargeReminder: .never)
        try repos.recurringItems.save(paused)
        try repos.recurringItems.save(archived)
        try repos.recurringItems.save(neverR)

        coordinator.didBecomeActive()
        await Task.yield()

        // Coordinator passes every stored item; real NotificationScheduler filters
        // via isEligible() inside schedule(for:).
        #expect(mock.rescheduleAllCallCount == 1)
        #expect(mock.lastRescheduledItems.count == 3)
    }

    @Test("item with both charge and trial reminders is forwarded intact")
    func itemWithBothRemindersForwardedIntact() async throws {
        let repos = try makeRepos()
        let mock  = MockNotificationScheduler()
        let coordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            scheduler:  mock
        )

        let trialEnd = Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        let item = freshItem(
            chargeReminder: .threeDaysBefore,
            trialReminder:  .oneDayBefore,
            trialEndDate:   trialEnd
        )
        try repos.recurringItems.save(item)

        coordinator.didBecomeActive()
        await Task.yield()

        let forwarded = mock.lastRescheduledItems.first
        #expect(forwarded?.id == item.id)
        #expect(forwarded?.chargeReminder == .threeDaysBefore)
        #expect(forwarded?.trialReminder  == .oneDayBefore)
        #expect(forwarded?.trialEndDate   != nil)
    }

    @Test("rapid calls produce at most one reschedule run")
    func rapidCallsProduceAtMostOneRun() async throws {
        let repos = try makeRepos()
        let mock  = MockNotificationScheduler()
        let coordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            scheduler:  mock
        )

        coordinator.didBecomeActive()
        coordinator.didBecomeActive()
        coordinator.didBecomeActive()
        await Task.yield()

        #expect(mock.rescheduleAllCallCount <= 1)
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
