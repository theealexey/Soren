import Testing
import Foundation
@testable import Soren

// MARK: - UserPreferencesRepository — defaultChargeReminder

/// Adversarial tests for the `defaultChargeReminder` preference:
/// round-trip persistence, unknown-rawValue resilience, isolation between
/// UserDefaults suites, and AddSubscriptionViewModel seeding behaviour.
@Suite("UserPreferencesRepository — defaultChargeReminder")
struct UserPreferencesReminderTests {

    /// Returns a repository backed by an isolated, empty UserDefaults suite
    /// so tests cannot interfere with each other or with the real app data.
    private func makeRepo() -> UserPreferencesRepository {
        let suiteName = "test.soren.prefs.\(UUID().uuidString)"
        let defaults  = UserDefaults(suiteName: suiteName)!
        return UserPreferencesRepository(defaults: defaults)
    }

    // MARK: - Round-trip

    @Test("Saved defaultChargeReminder is returned on next load")
    func roundTrip() {
        let repo = makeRepo()
        for option in ChargeReminderOption.allCases {
            var prefs = repo.load()
            prefs.defaultChargeReminder = option
            repo.save(prefs)
            #expect(repo.load().defaultChargeReminder == option,
                    "Round-trip failed for \(option)")
        }
    }

    // MARK: - Default value

    @Test("Fresh UserDefaults returns .threeDaysBefore as default")
    func freshDefaultIsThreeDays() {
        let repo = makeRepo()
        #expect(repo.load().defaultChargeReminder == .threeDaysBefore)
    }

    // MARK: - Resilience

    @Test("Unknown rawValue in UserDefaults falls back to .threeDaysBefore")
    func unknownRawValueFallback() {
        let suiteName = "test.soren.prefs.\(UUID().uuidString)"
        let defaults  = UserDefaults(suiteName: suiteName)!
        defaults.set("twoWeeksBefore", forKey: "soren.defaultChargeReminder")
        let repo = UserPreferencesRepository(defaults: defaults)
        #expect(repo.load().defaultChargeReminder == .threeDaysBefore)
    }

    // MARK: - Other fields untouched

    @Test("Saving defaultChargeReminder does not overwrite defaultCurrencyCode")
    func savingReminderPreservesCurrency() {
        let repo  = makeRepo()
        var prefs = repo.load()
        prefs.defaultCurrencyCode = "USD"
        repo.save(prefs)

        var prefs2 = repo.load()
        prefs2.defaultChargeReminder = .never
        repo.save(prefs2)

        #expect(repo.load().defaultCurrencyCode == "USD")
    }
}

// MARK: - AddSubscriptionViewModel — seeding from preferences

@Suite("AddSubscriptionViewModel — chargeReminder seeding")
@MainActor
struct AddSubscriptionViewModelReminderSeedingTests {

    /// Builds a ViewModel backed by an in-memory container and a custom
    /// preferences repository pre-populated with the given reminder option.
    private func makeVM(defaultReminder: ChargeReminderOption) throws -> AddSubscriptionViewModel {
        let suiteName = "test.soren.seed.\(UUID().uuidString)"
        let defaults  = UserDefaults(suiteName: suiteName)!
        let repo      = UserPreferencesRepository(defaults: defaults)
        var prefs     = repo.load()
        prefs.defaultChargeReminder = defaultReminder
        repo.save(prefs)

        let container  = try SorenModelContainer.inMemory()
        let repos      = RepositoryContainer(context: container.mainContext)
        return AddSubscriptionViewModel(
            catalog:           InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repos.recurringItems),
            preferences:       repo
        )
    }

    @Test("chargeReminder is seeded from .never preference")
    func seedsNever() throws {
        let vm = try makeVM(defaultReminder: .never)
        #expect(vm.chargeReminder == .never)
    }

    @Test("chargeReminder is seeded from .sameDay preference")
    func seedsSameDay() throws {
        let vm = try makeVM(defaultReminder: .sameDay)
        #expect(vm.chargeReminder == .sameDay)
    }

    @Test("chargeReminder is seeded from .sevenDaysBefore preference")
    func seedsSevenDays() throws {
        let vm = try makeVM(defaultReminder: .sevenDaysBefore)
        #expect(vm.chargeReminder == .sevenDaysBefore)
    }

    @Test("startManualEntry() resets chargeReminder to current default preference")
    func startManualEntryResetsToDefault() throws {
        let vm = try makeVM(defaultReminder: .oneDayBefore)
        // Simulate user having overridden the reminder in the form
        vm.chargeReminder = .sevenDaysBefore
        vm.startManualEntry()
        // Should snap back to the saved preference, not the overridden value
        #expect(vm.chargeReminder == .oneDayBefore)
    }

    @Test("User override in the form does not persist to preferences")
    func formOverrideDoesNotPersist() throws {
        let suiteName = "test.soren.seed.\(UUID().uuidString)"
        let defaults  = UserDefaults(suiteName: suiteName)!
        let repo      = UserPreferencesRepository(defaults: defaults)
        var prefs     = repo.load()
        prefs.defaultChargeReminder = .threeDaysBefore
        repo.save(prefs)

        let container  = try SorenModelContainer.inMemory()
        let repos      = RepositoryContainer(context: container.mainContext)
        let vm         = AddSubscriptionViewModel(
            catalog:           InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repos.recurringItems),
            preferences:       repo
        )

        vm.chargeReminder = .never   // user changes in form — should not write to prefs

        // A fresh ViewModel reading the same store should still see .threeDaysBefore
        let vm2 = AddSubscriptionViewModel(
            catalog:           InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repos.recurringItems),
            preferences:       repo
        )
        #expect(vm2.chargeReminder == .threeDaysBefore)
    }
}
