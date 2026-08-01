import Testing
import Foundation
@testable import Soren

@Suite("UpdateRecurringItem notification reconciliation")
@MainActor
struct UpdateRecurringItemSchedulingTests {
    @Test("update persists first and awaits complete reconciliation")
    func updateReconciles() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        let coordinator = NotificationReconciliationSpy()
        let result = try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(item)
        #expect(result.item.id == item.id)
        #expect(coordinator.callCount == 1)
    }

    @Test("validation failure does not reconcile")
    func validationFailureDoesNotReconcile() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        item.title = " "
        let coordinator = NotificationReconciliationSpy()
        await #expect(throws: UpdateRecurringItem.ValidationError.emptyTitle) {
            try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(item)
        }
        #expect(coordinator.callCount == 0)
    }

    @Test("paused update still reconciles the complete desired state")
    func pausedUpdateReconciles() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        item.status = .paused
        try fixture.recurringItems.save(item)
        let coordinator = NotificationReconciliationSpy()
        _ = try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(item)
        #expect(coordinator.callCount == 1)
    }

    @Test("archived update still reconciles the complete desired state")
    func archivedUpdateReconciles() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        item.status = .archived
        try fixture.recurringItems.save(item)
        let coordinator = NotificationReconciliationSpy()
        _ = try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(item)
        #expect(coordinator.callCount == 1)
    }

    @Test("update succeeds without an optional notification coordinator")
    func updateWithoutCoordinatorReturnsNoOutcome() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        let result = try await UpdateRecurringItem(repository: fixture.recurringItems).execute(item)
        #expect(result.notificationOutcome == nil)
    }

    @Test("partial notification outcome does not roll back an update")
    func partialOutcomeDoesNotRollBackUpdate() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var item = RecurringItem(title: "Spotify", amount: 299, nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        item.title = "Spotify Premium"
        let coordinator = NotificationReconciliationSpy()
        coordinator.outcome = .repositoryFetchFailed
        let result = try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(item)
        #expect(result.notificationOutcome == .repositoryFetchFailed)
        #expect(try fixture.recurringItems.fetch(id: item.id)?.title == "Spotify Premium")
    }
}
