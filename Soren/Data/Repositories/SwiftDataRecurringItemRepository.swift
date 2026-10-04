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
    private let saveContext: (ModelContext) throws -> Void

    init(container: ModelContainer, save: @escaping (ModelContext) throws -> Void = { try $0.save() }) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context
        self.saveContext = save
    }

    /// Compatibility entry point; the caller's pending changes are never owned here.
    convenience init(context: ModelContext) {
        self.init(container: context.container)
    }

    // MARK: - Read

    func fetchAll() throws -> [RecurringItem] {
        let descriptor = FetchDescriptor<SDRecurringItem>()
        return try context.fetch(descriptor).map(RecurringItemMapper.toDomain).sorted(by: canonicalOrder)
    }

    func fetchActive() throws -> [RecurringItem] {
        // Fetch all non-archived, then filter statuses in-memory.
        // SwiftData #Predicate doesn't support array.contains() on captured [String] in iOS 18.
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in item.archivedAt == nil }
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
            .sorted(by: canonicalOrder)
    }

    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
        _ = try BillingCivilDay.civilDate(fromCanonicalDate: date)
        guard days > 0 else { return [] }
        guard let cutoff = BillingCivilDay.calendar.date(byAdding: .day, value: days, to: date) else {
            throw BillingCivilDayError.arithmeticFailed
        }
        _ = try BillingCivilDay.civilDate(fromCanonicalDate: cutoff)
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { item in
                item.archivedAt == nil
            }
        )
        return try context.fetch(descriptor).map(RecurringItemMapper.toDomain)
            .filter { $0.nextChargeDate >= date && $0.nextChargeDate <= cutoff }
            .sorted(by: canonicalOrder)
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
        let sd = try RecurringItemMapper.toSD(item)
        context.insert(sd)
        try commit()
    }

    func update(_ item: RecurringItem) throws {
        let targetID = item.id
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else {
            throw RepositoryError.notFound(item.id)
        }
        try RecurringItemMapper.update(sd, from: item)
        try commit()
    }

    func delete(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<SDRecurringItem>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else { return }
        context.delete(sd)
        try commit()
    }

    // MARK: - Bulk

    func saveAll(_ items: [RecurringItem]) throws {
        let prepared = try items.map(RecurringItemMapper.toSD)
        for sd in prepared { context.insert(sd) }
        try commit()
    }

    func deleteAll() throws {
        try context.delete(model: SDRecurringItem.self)
        try commit()
    }

    private func canonicalOrder(_ lhs: RecurringItem, _ rhs: RecurringItem) -> Bool {
        if lhs.nextChargeDate != rhs.nextChargeDate { return lhs.nextChargeDate < rhs.nextChargeDate }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func commit() throws {
        do { try saveContext(context) }
        catch {
            context.rollback()
            throw error
        }
    }
}
