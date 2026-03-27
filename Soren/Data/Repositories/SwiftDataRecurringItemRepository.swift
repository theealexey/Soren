import Foundation
import SwiftData

// MARK: - SwiftData Repository: Recurring Items

/// Concrete implementation of RecurringItemRepository backed by SwiftData.
///
/// Design decisions:
/// - `@MainActor` because ModelContext is not Sendable and must run on main thread
/// - `#Predicate` only captures primitive values (UUID, String, Date, Bool) — not structs/enums
/// - Status/category filtering is done in-memory after a narrow DB fetch to work around
///   SwiftData predicate limitations with array `.contains()` on iOS 18+
@MainActor
final class SwiftDataRecurringItemRepository: RecurringItemRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Read

    func fetchAll() throws -> [RecurringItem] {
        let descriptor = FetchDescriptor<SDRecurringItem>(
            sortBy: [SortDescriptor(\.nextChargeDate)]
        )
        return try context.fetch(descriptor).map(RecurringItemMapper.toDomain)
    }

    func fetchActive() throws -> [RecurringItem] {
        // Fetch all non-archived, then filter statuses in-memory.
        // SwiftData #Predicate doesn't support array.contains() on captured [String] in iOS 18.
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in item.archivedAt == nil },
            sortBy: [SortDescriptor(\.nextChargeDate)]
        )
        let activeStatuses: Set<String> = [
            ItemStatus.active.rawValue,
            ItemStatus.dueSoon.rawValue,
            ItemStatus.dueToday.rawValue,
            ItemStatus.trial.rawValue
        ]
        return try context.fetch(descriptor)
            .filter { activeStatuses.contains($0.statusRaw) }
            .map(RecurringItemMapper.toDomain)
    }

    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
        guard days > 0 else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in
                item.nextChargeDate >= date
                && item.nextChargeDate <= cutoff
                && item.archivedAt == nil
            },
            sortBy: [SortDescriptor(\.nextChargeDate)]
        )
        return try context.fetch(descriptor).map(RecurringItemMapper.toDomain)
    }

    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in
                item.categoryRaw == raw && item.archivedAt == nil
            },
            sortBy: [SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor).map(RecurringItemMapper.toDomain)
    }

    func fetch(id: UUID) throws -> RecurringItem? {
        // Capture primitive UUID — not RecurringItem struct — for #Predicate compatibility
        let targetID = id
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in item.id == targetID }
        )
        return try context.fetch(descriptor).first.map(RecurringItemMapper.toDomain)
    }

    // MARK: - Write

    func save(_ item: RecurringItem) throws {
        let sd = RecurringItemMapper.toSD(item)
        context.insert(sd)
        try context.save()
    }

    func update(_ item: RecurringItem) throws {
        let targetID = item.id
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound(item.id)
        }
        RecurringItemMapper.update(sd, from: item)
        try context.save()
    }

    func delete(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else { return }
        context.delete(sd)
        try context.save()
    }

    // MARK: - Bulk

    func saveAll(_ items: [RecurringItem]) throws {
        for item in items {
            context.insert(RecurringItemMapper.toSD(item))
        }
        try context.save()
    }

    func deleteAll() throws {
        try context.delete(model: SDRecurringItem.self)
        try context.save()
    }
}
