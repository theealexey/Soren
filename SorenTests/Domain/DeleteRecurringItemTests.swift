import Testing
import Foundation
@testable import Soren

// MARK: - DeleteRecurringItem — notification cancellation tests

/// Verifies that DeleteRecurringItem triggers the notification scheduler exactly
/// when and only when the item is successfully removed from persistence.
///
/// execute(id:) is async throws and directly awaits scheduler.cancel(for:),
/// so assertions are deterministic — no Task.yield or scheduling tricks needed.

@Suite("DeleteRecurringItem — notification cancellation")
@MainActor
struct DeleteRecurringItemCancellationTests {

    // MARK: - Cancel fires on success

    @Test("Successful delete triggers cancel(for:) with the item's ID")
    func cancelFiredOnSuccess() async throws {
        let mock = MockNotificationScheduler()
        let uc   = DeleteRecurringItem(
            repository: SucceedingDeleteRepository(),
            notificationScheduler: mock
        )
        let id = UUID()

        try await uc.execute(id: id)

        #expect(mock.cancelledIDs.contains(id))
    }

    @Test("Successful delete triggers cancel exactly once")
    func cancelledExactlyOnce() async throws {
        let mock = MockNotificationScheduler()
        let uc   = DeleteRecurringItem(
            repository: SucceedingDeleteRepository(),
            notificationScheduler: mock
        )

        try await uc.execute(id: UUID())

        #expect(mock.cancelledIDs.count == 1)
    }

    // MARK: - Nil scheduler

    @Test("Nil scheduler completes without crash and item is removed")
    func noSchedulerMeansNoCrash() async throws {
        let container = try SorenModelContainer.inMemory()
        let repo      = SwiftDataRecurringItemRepository(context: container.mainContext)
        let item      = RecurringItem(
            title: "Netflix",
            amount: 699,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        )
        try repo.save(item)

        let uc = DeleteRecurringItem(repository: repo, notificationScheduler: nil)
        try await uc.execute(id: item.id)

        let fetched = try repo.fetch(id: item.id)
        #expect(fetched == nil)
    }

    // MARK: - Cancel blocked on repository failure

    @Test("Repository failure does not trigger cancel")
    func repositoryFailureDoesNotCancel() async throws {
        let mock = MockNotificationScheduler()
        let uc   = DeleteRecurringItem(
            repository: FailingDeleteRepository(),
            notificationScheduler: mock
        )

        await #expect(throws: FailingDeleteRepository.DeleteError.self) {
            try await uc.execute(id: UUID())
        }

        #expect(mock.cancelledIDs.isEmpty)
    }
}

// MARK: - SucceedingDeleteRepository

/// Minimal repository stub whose delete always succeeds silently.
/// Lets scheduler tests verify the notification side-effect in isolation,
/// without coupling to SwiftData container lifetime in async test functions.
@MainActor
private final class SucceedingDeleteRepository: RecurringItemRepository {
    func fetchAll() throws -> [RecurringItem]                                        { [] }
    func fetchActive() throws -> [RecurringItem]                                     { [] }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem]  { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem]         { [] }
    func fetch(id: UUID) throws -> RecurringItem?                                    { nil }
    func save(_ item: RecurringItem) throws                                          {}
    func update(_ item: RecurringItem) throws                                        {}
    func delete(id: UUID) throws                                                     {}
    func saveAll(_ items: [RecurringItem]) throws                                    {}
    func deleteAll() throws                                                          {}
}

// MARK: - FailingDeleteRepository

/// Minimal repository stub that always throws on delete(id:).
@MainActor
private final class FailingDeleteRepository: RecurringItemRepository {
    struct DeleteError: Error {}

    func fetchAll() throws -> [RecurringItem]                                        { [] }
    func fetchActive() throws -> [RecurringItem]                                     { [] }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem]  { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem]         { [] }
    func fetch(id: UUID) throws -> RecurringItem?                                    { nil }
    func save(_ item: RecurringItem) throws                                          {}
    func update(_ item: RecurringItem) throws                                        {}
    func delete(id: UUID) throws                                                     { throw DeleteError() }
    func saveAll(_ items: [RecurringItem]) throws                                    {}
    func deleteAll() throws                                                          {}
}
