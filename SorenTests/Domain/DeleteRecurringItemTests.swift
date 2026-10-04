import Testing
import Foundation
@testable import Soren

@Suite("DeleteRecurringItem notification reconciliation")
@MainActor
struct DeleteRecurringItemCancellationTests {
    @Test("delete reconciles complete state after persistence")
    func deleteReconciles() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let item = RecurringItem(title: "Netflix", amount: 699, startDate: Date(timeIntervalSinceReferenceDate: 0), nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        let coordinator = NotificationReconciliationSpy()
        let outcome = try await DeleteRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(id: item.id)
        #expect(outcome != nil)
        #expect(coordinator.callCount == 1)
        #expect(try fixture.recurringItems.fetch(id: item.id) == nil)
    }

    @Test("delete succeeds without an optional notification coordinator")
    func deleteWithoutCoordinatorReturnsNoOutcome() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let item = RecurringItem(title: "Netflix", amount: 699, startDate: Date(timeIntervalSinceReferenceDate: 0), nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        let outcome = try await DeleteRecurringItem(repository: fixture.recurringItems).execute(id: item.id)
        #expect(outcome == nil)
        #expect(try fixture.recurringItems.fetch(id: item.id) == nil)
    }

    @Test("delete retains a nonfatal reconciliation outcome")
    func deleteReturnsNonfatalOutcome() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let item = RecurringItem(title: "Netflix", amount: 699, startDate: Date(timeIntervalSinceReferenceDate: 0), nextChargeDate: .distantFuture)
        try fixture.recurringItems.save(item)
        let coordinator = NotificationReconciliationSpy()
        coordinator.outcome = .repositoryFetchFailed
        let outcome = try await DeleteRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(id: item.id)
        #expect(outcome == .repositoryFetchFailed)
        #expect(try fixture.recurringItems.fetch(id: item.id) == nil)
    }
}
