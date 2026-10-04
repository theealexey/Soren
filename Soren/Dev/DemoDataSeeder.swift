#if DEBUG
import Foundation

// MARK: - Demo Data Seeder

/// Seeds and clears the App Store screenshot demo dataset.
///
/// All 15 items are tagged ``DemoDataSeeder/demoTag`` so they can be
/// identified and removed without touching real user data.
///
/// Safety contract:
/// - ``seed(relativeTo:calendar:)`` is idempotent — no-ops if demo data
///   is already present.
/// - ``clear()`` removes only items whose `tags` contain `demoTag`.
///   Real user subscriptions are never touched.
/// - No data is written unless the caller explicitly invokes `seed()`.
/// - This entire file is excluded from Release builds via `#if DEBUG`.
@MainActor
struct DemoDataSeeder {

    // MARK: - Tag

    /// Marker applied to every seeded item. Used for identification and bulk deletion.
    /// `nonisolated` so it can be referenced from non-actor contexts (e.g. DemoSeedItems).
    nonisolated static let demoTag = "screenshot-demo"

    // MARK: - Dependencies

    private let repository: any RecurringItemRepository
    private let preferences: UserPreferencesRepository

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository()
    ) {
        self.repository = repositories.recurringItems
        self.preferences = preferences
    }

    // MARK: - State

    /// Returns `true` if at least one item with ``demoTag`` exists in the store.
    var isDemoDataPresent: Bool {
        (try? repository.fetchAll())?.contains { $0.tags.contains(Self.demoTag) } ?? false
    }

    // MARK: - Seed

    /// Inserts 15 demo subscriptions relative to `date`.
    ///
    /// All charge dates are computed from `date` so the Calendar, Alerts,
    /// and Analytics screens always look fresh regardless of when this is called.
    ///
    /// Also sets the default currency to RUB so header totals render in ₽.
    ///
    /// - Note: No-ops if demo data is already present (idempotent).
    func seed(relativeTo date: Date = .now, calendar: Calendar = .current) throws {
        guard !isDemoDataPresent else { return }
        let items = try DemoSeedItems.items(relativeTo: date, calendar: calendar)
        for item in items {
            try repository.save(item)
        }
        var prefs = preferences.load()
        prefs.defaultCurrencyCode = "RUB"
        preferences.save(prefs)
    }

    // MARK: - Clear

    /// Deletes all items that carry ``demoTag``.
    /// Leaves all real user subscriptions untouched.
    func clear() throws {
        let all = try repository.fetchAll()
        let demo = all.filter { $0.tags.contains(Self.demoTag) }
        for item in demo {
            try repository.delete(id: item.id)
        }
    }
}
#endif
