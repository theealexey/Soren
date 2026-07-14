import Testing
import Foundation
import Observation
@testable import Soren

// MARK: - LibraryViewModel — Search Debounce Tests

@MainActor
private final class LibrarySearchTestRepository: RecurringItemRepository {
    private var items: [RecurringItem] = []

    func fetchAll() throws -> [RecurringItem] { items }
    func fetchActive() throws -> [RecurringItem] { items.filter { $0.status.countsInTotals } }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        items.filter { $0.category == category }
    }
    func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
    func save(_ item: RecurringItem) throws { items.append(item) }
    func update(_ item: RecurringItem) throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }
    func delete(id: UUID) throws { items.removeAll { $0.id == id } }
    func saveAll(_ items: [RecurringItem]) throws { self.items.append(contentsOf: items) }
    func deleteAll() throws { items.removeAll() }
}

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

    private func makeVM(delay: Duration = .zero) -> (LibraryViewModel, LibrarySearchTestRepository) {
        let repository = LibrarySearchTestRepository()
        let vm = LibraryViewModel(
            getLibraryItems: GetLibraryItems(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            searchDebounceDelay: delay
        )
        return (vm, repository)
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

    private func waitForFilteredItemsChange(
        in viewModel: LibraryViewModel,
        action: () -> Void
    ) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = viewModel.filteredItems
            } onChange: {
                continuation.resume()
            }
            action()
        }
    }

    // MARK: - Search correctness

    @Test("Case-insensitive match on title")
    func searchMatchesTitle() async throws {
        let (vm, repository) = makeVM()
        try repository.save(item(title: "Spotify"))
        try repository.save(item(title: "Netflix"))
        vm.load()

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "spot"
        }

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Spotify"])
    }

    @Test("Clearing search returns all active items")
    func clearingSearchRestoresAll() async throws {
        let (vm, repository) = makeVM()
        try repository.save(item(title: "Spotify"))
        try repository.save(item(title: "Netflix"))
        vm.load()

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "spo"
        }

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = ""
        }

        #expect(vm.sections.flatMap(\.items).count == 2)
    }

    @Test("No results for unmatched query")
    func noResultsForUnmatchedQuery() async throws {
        let (vm, repository) = makeVM()
        try repository.save(item(title: "Spotify"))
        vm.load()

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "zzz"
        }

        #expect(vm.sections.flatMap(\.items).isEmpty)
    }

    @Test("Multiple items matching same query all appear")
    func multipleMatchesAllAppear() async throws {
        let (vm, repository) = makeVM()
        try repository.save(item(title: "Spotify"))
        try repository.save(item(title: "Spotless Vinyl"))
        try repository.save(item(title: "Netflix"))
        vm.load()

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "spot"
        }

        let titles = Set(vm.sections.flatMap(\.items).map(\.title))
        #expect(titles == Set(["Spotify", "Spotless Vinyl"]))
    }

    // MARK: - Filter immediacy

    @Test("activeFilter change triggers immediate recompute with current searchText")
    func filterChangeIsImmediate() async throws {
        let (vm, repository) = makeVM()
        var paused = item(title: "Paused Sub")
        paused.status = .paused
        try repository.save(paused)
        try repository.save(item(title: "Active Sub"))
        vm.load()

        vm.activeFilter = .paused

        // No yield needed — filter.didSet calls recompute() synchronously.
        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Paused Sub"])
    }

    @Test("activeFilter change with pending debounced search uses current searchText")
    func filterCancelsPendingSearch() async throws {
        // Use real delay so the task is genuinely pending when we change filter.
        let (vm, repository) = makeVM(delay: .milliseconds(150))
        try repository.save(item(title: "Spotify"))
        try repository.save(item(title: "Netflix"))
        var paused = item(title: "Paused Spotify")
        paused.status = .paused
        try repository.save(paused)
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
        let (vm, repository) = makeVM()
        let soon = Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        let late = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let a = RecurringItem(title: "Alpha", amount: 1, nextChargeDate: late)
        let b = RecurringItem(title: "Beta",  amount: 2, nextChargeDate: soon)
        try repository.save(a)
        try repository.save(b)
        vm.load()

        vm.sortOrder = .name

        let titles = vm.sections.flatMap(\.items).map(\.title)
        #expect(titles == ["Alpha", "Beta"])
    }

    // MARK: - sections structure

    @Test("sections collapses to single unnamed section during active search")
    func searchProducesSingleSection() async throws {
        let (vm, repository) = makeVM()
        try repository.save(item(title: "Spotify"))
        try repository.save(item(title: "Netflix"))
        vm.load()

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "Spo"
        }

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
        let repository = LibrarySearchTestRepository()
        let vm = LibraryViewModel(
            getLibraryItems: GetLibraryItems(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            searchDebounceDelay: .milliseconds(150)
        )

        for title in ["Spotify", "Netflix", "YouTube", "Apple TV", "Disney+"] {
            try repository.save(item(title: title))
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
        let repository = LibrarySearchTestRepository()
        let vm = LibraryViewModel(
            getLibraryItems: GetLibraryItems(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            searchDebounceDelay: .milliseconds(150)
        )

        try repository.save(item(title: "Netflix"))
        try repository.save(item(title: "Neon Signs"))   // matches "Ne", "Neo" but not "Netf"
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
