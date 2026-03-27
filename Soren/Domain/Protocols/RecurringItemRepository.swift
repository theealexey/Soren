import Foundation

/// Contract for all recurring item persistence operations.
/// The concrete implementation (SwiftData) lives in the Data layer.
/// ViewModels depend on this protocol — never on the concrete type.
/// Contract for all recurring item persistence operations.
/// Deliberately synchronous + @MainActor — SwiftData requires main thread,
/// and making these async would be an architectural lie hiding sync work behind await.
@MainActor
protocol RecurringItemRepository: AnyObject {

    // MARK: - Read

    func fetchAll() throws -> [RecurringItem]
    func fetchActive() throws -> [RecurringItem]
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem]
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem]
    func fetch(id: UUID) throws -> RecurringItem?

    // MARK: - Write

    func save(_ item: RecurringItem) throws
    func update(_ item: RecurringItem) throws
    func delete(id: UUID) throws

    // MARK: - Bulk

    func saveAll(_ items: [RecurringItem]) throws
    func deleteAll() throws
}
