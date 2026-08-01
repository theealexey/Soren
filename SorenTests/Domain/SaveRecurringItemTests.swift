import Testing
import Foundation
@testable import Soren

@Suite("SaveRecurringItem notification reconciliation")
@MainActor
struct SaveRecurringItemNotificationTests {
    private func item(title: String = "Spotify", amount: Decimal = 299) -> RecurringItem {
        RecurringItem(title: title, amount: amount, nextChargeDate: .distantFuture)
    }

    @Test("successful save awaits complete reconciliation after persistence")
    func successfulSaveReconciles() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let coordinator = NotificationReconciliationSpy()
        let useCase = SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator)
        let saved = try await useCase.execute(item())
        #expect(saved.item.title == "Spotify")
        #expect(coordinator.callCount == 1)
        #expect(try fixture.recurringItems.fetch(id: saved.item.id) != nil)
    }

    @Test("validation failure does not reconcile")
    func validationFailureDoesNotReconcile() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let coordinator = NotificationReconciliationSpy()
        let useCase = SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator)
        await #expect(throws: SaveRecurringItem.ValidationError.emptyTitle) {
            try await useCase.execute(item(title: " "))
        }
        #expect(coordinator.callCount == 0)
    }

    @Test("reconciliation outcome is nonfatal after persisted save")
    func reconciliationOutcomeIsReturned() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let coordinator = NotificationReconciliationSpy()
        coordinator.outcome = .repositoryFetchFailed
        let useCase = SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator)
        let result = try await useCase.execute(item())
        #expect(result.notificationOutcome == .repositoryFetchFailed)
        #expect(try fixture.recurringItems.fetch(id: result.item.id) != nil)
    }

    @Test("save succeeds without an optional notification coordinator")
    func saveWithoutCoordinatorReturnsNoOutcome() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let result = try await SaveRecurringItem(repository: fixture.recurringItems).execute(item())
        #expect(result.notificationOutcome == nil)
        #expect(try fixture.recurringItems.fetch(id: result.item.id) != nil)
    }

    @Test("zero amount validation does not reconcile")
    func zeroAmountDoesNotReconcile() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let coordinator = NotificationReconciliationSpy()
        let useCase = SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator)
        await #expect(throws: SaveRecurringItem.ValidationError.invalidAmount) {
            try await useCase.execute(item(amount: 0))
        }
        #expect(coordinator.callCount == 0)
    }

    @Test("finite end date before the next charge does not reconcile")
    func invalidFiniteEndDateDoesNotReconcile() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var subscription = item()
        subscription.autoRenew = false
        subscription.endDate = .distantPast
        let coordinator = NotificationReconciliationSpy()
        let useCase = SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator)
        await #expect(throws: SaveRecurringItem.ValidationError.endDateBeforeNextCharge) {
            try await useCase.execute(subscription)
        }
        #expect(coordinator.callCount == 0)
    }

    @Test("auto-renew save clears an obsolete finite end date before reconciliation")
    func autoRenewClearsEndDateBeforeReconciliation() async throws {
        let fixture = try InMemoryPersistenceFixture()
        var subscription = item()
        subscription.autoRenew = true
        subscription.endDate = .distantFuture
        let result = try await SaveRecurringItem(repository: fixture.recurringItems).execute(subscription)
        #expect(result.item.endDate == nil)
    }
}
