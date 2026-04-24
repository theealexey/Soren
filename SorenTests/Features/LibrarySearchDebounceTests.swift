import Testing
import Foundation
@testable import Soren

// MARK: - LibraryViewModel — Search Debounce Tests

/// Tests are split into two groups:
///   • Zero-delay tests  — use `searchDebounceDelay: .zero` so no real wall-clock
///     waiting is needed; correctness of filtering, sorting, and filter/sort
///     immediacy are verified here.
///   • Timing tests      — use a real 150 ms delay to verify that rapid keystrokes
///     coalesce into a single recompute and the final result matches only the
///     last query, not any intermediate one.

@Suite("LibraryViewModel — search debounce (zero-delay correctness)")
@MainActor
struct LibrarySearchDebounceCorrectnessTests {

    // MARK: - Fixtures

    private func makeVM(delay: Duration = .zero) throws -> (LibraryViewModel, RepositoryContainer) {
        let mc    = try SorenModelContainer.inMemory()
        let repos = RepositoryContainer(context: mc.mainContext)
        let vm    = LibraryViewModel(repositories: repos, searchDebounceDelay: delay)
        return (vm, repos)
    }

    private func item(title: String, status: ItemStatus = .active) -> RecurringItem {
        var i = RecurringItem(
            title:          title,
            amount:         9.99,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
        i.status = status
        return i
    }

    // MARK: - Search correctness

    @Test("Case-insensitive match on title")
    func searchMatchesTitle() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(item(title: "Spotify"))
        try repos.recurringItems.save(item(title: "Netflix"))
        vm.load()

        vm.searchText = "spot"
        await Task.yield(); await Task.yield()

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Spotify"])
    }

    @Test("Clearing search returns all active items")
    func clearingSearchRestoresAll() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(item(title: "Spotify"))
        try repos.recurringItems.save(item(title: "Netflix"))
        vm.load()

        vm.searchText = "spo"
        await Task.yield(); await Task.yield()

        vm.searchText = ""
        await Task.yield(); await Task.yield()

        #expect(vm.sections.flatMap(\.items).count == 2)
    }

    @Test("No results for unmatched query")
    func noResultsForUnmatchedQuery() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(item(title: "Spotify"))
        vm.load()

        vm.searchText = "zzz"
        await Task.yield(); await Task.yield()

        #expect(vm.sections.flatMap(\.items).isEmpty)
    }

    @Test("Multiple items matching same query all appear")
    func multipleMatchesAllAppear() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(item(title: "Spotify"))
        try repos.recurringItems.save(item(title: "Spotless Vinyl"))
        try repos.recurringItems.save(item(title: "Netflix"))
        vm.load()

        vm.searchText = "spot"
        await Task.yield(); await Task.yield()

        let titles = Set(vm.sections.flatMap(\.items).map(\.title))
        #expect(titles == Set(["Spotify", "Spotless Vinyl"]))
    }

    // MARK: - Filter immediacy

    @Test("activeFilter change triggers immediate recompute with current searchText")
    func filterChangeIsImmediate() async throws {
        let (vm, repos) = try makeVM()
        var paused = item(title: "Paused Sub")
        paused.status = .paused
        try repos.recurringItems.save(paused)
        try repos.recurringItems.save(item(title: "Active Sub"))
        vm.load()

        vm.activeFilter = .paused

        // No yield needed — filter.didSet calls recompute() synchronously.
        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Paused Sub"])
    }

    @Test("activeFilter change with pending debounced search uses current searchText")
    func filterCancelsPendingSearch() async throws {
        // Use real delay so the task is genuinely pending when we change filter.
        let (vm, repos) = try makeVM(delay: .milliseconds(150))
        try repos.recurringItems.save(item(title: "Spotify"))
        try repos.recurringItems.save(item(title: "Netflix"))
        var paused = item(title: "Paused Spotify")
        paused.status = .paused
        try repos.recurringItems.save(paused)
        vm.load()

        // Start a debounced search — task is pending, not yet fired.
        vm.searchText = "spotify"

        // Immediately change filter — should cancel debounce and recompute with
        // the current searchText ("spotify") and the new filter (.paused).
        vm.activeFilter = .paused

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Paused Spotify"])
    }

    // MARK: - Sort immediacy

    @Test("sortOrder change triggers immediate recompute")
    func sortChangeIsImmediate() async throws {
        let (vm, repos) = try makeVM()
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let late = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let a = RecurringItem(title: "Alpha", amount: 1, nextChargeDate: late)
        let b = RecurringItem(title: "Beta",  amount: 2, nextChargeDate: soon)
        try repos.recurringItems.save(a)
        try repos.recurringItems.save(b)
        vm.load()

        vm.sortOrder = .name

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Alpha", "Beta"])
    }

    // MARK: - sections structure

    @Test("sections collapses to single unnamed section during active search")
    func searchProducesSingleSection() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(item(title: "Spotify"))
        try repos.recurringItems.save(item(title: "Netflix"))
        vm.load()

        vm.searchText = "Spo"
        await Task.yield(); await Task.yield()

        #expect(vm.sections.count == 1)
        #expect(vm.sections.first?.title == nil)
    }
}

// MARK: - Timing tests (real debounce delay)

@Suite("LibraryViewModel — search debounce (timing)")
@MainActor
struct LibrarySearchDebounceTimingTests {

    private func item(title: String) -> RecurringItem {
        RecurringItem(
            title:          title,
            amount:         9.99,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
    }

    @Test("Rapid keystrokes coalesce — only last query drives the final result")
    func rapidChangesCoalesceToLastQuery() async throws {
        let mc    = try SorenModelContainer.inMemory()
        let repos = RepositoryContainer(context: mc.mainContext)
        let vm    = LibraryViewModel(repositories: repos, searchDebounceDelay: .milliseconds(150))

        for title in ["Spotify", "Netflix", "YouTube", "Apple TV", "Disney+"] {
            try repos.recurringItems.save(item(title: title))
        }
        vm.load()

        // Simulate rapid typing: each assignment cancels the previous debounce task.
        vm.searchText = "S"
        vm.searchText = "Sp"
        vm.searchText = "Spo"   // ← last; only this one's timer survives

        // Wait longer than the debounce delay; only "Spo" should have fired.
        try await Task.sleep(for: .milliseconds(300))

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Spotify"])
    }

    @Test("Final result matches last query, not any intermediate query")
    func finalResultMatchesLastQuery() async throws {
        let mc    = try SorenModelContainer.inMemory()
        let repos = RepositoryContainer(context: mc.mainContext)
        let vm    = LibraryViewModel(repositories: repos, searchDebounceDelay: .milliseconds(150))

        try repos.recurringItems.save(item(title: "Netflix"))
        try repos.recurringItems.save(item(title: "Neon Signs"))   // matches "Ne", "Neo" but not "Netf"
        vm.load()

        vm.searchText = "Ne"    // matches both
        vm.searchText = "Net"   // matches Netflix
        vm.searchText = "Netf"  // ← last; matches only Netflix

        try await Task.sleep(for: .milliseconds(300))

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Netflix"])
        #expect(!titles.contains("Neon Signs"))
    }
}
