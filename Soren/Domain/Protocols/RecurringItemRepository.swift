import Foundation

/// Contract for all recurring item persistence operations.
/// The concrete implementation (SwiftData) lives in the Data layer.
/// ViewModels depend on this protocol — never on the concrete type.
protocol RecurringItemRepository: Sendable {

    // MARK: - Read

    func fetchAll() async throws -> [RecurringItem]
    func fetchActive() async throws -> [RecurringItem]
    func fetchUpcoming(within days: Int, from date: Date) async throws -> [RecurringItem]
    func fetchByCategory(_ category: ItemCategory) async throws -> [RecurringItem]
    func fetch(id: UUID) async throws -> RecurringItem?

    // MARK: - Write

    func save(_ item: RecurringItem) async throws
    func update(_ item: RecurringItem) async throws
    func delete(id: UUID) async throws

    // MARK: - Bulk

    func saveAll(_ items: [RecurringItem]) async throws
    func deleteAll() async throws
}
