import Foundation

// MARK: - Library View Model

/// Drives the Library screen with search, filtering, and sorting.
/// All filtering and sorting happens in-memory on the fetched dataset
/// via computed properties — @Observable triggers re-render automatically.
@MainActor @Observable
final class LibraryViewModel {

    // MARK: - User Input State

    var searchText = ""
    var activeFilter: StatusFilter = .all
    var sortOrder: SortOrder = .nextCharge

    // MARK: - Data State

    private(set) var allItems: [RecurringItem] = []
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getLibraryItems: GetLibraryItems
    private let preferences: UserPreferencesRepository

    // MARK: - Init

    init(getLibraryItems: GetLibraryItems, preferences: UserPreferencesRepository = UserPreferencesRepository()) {
        self.getLibraryItems = getLibraryItems
        self.preferences = preferences
    }

    init(repositories: RepositoryContainer, preferences: UserPreferencesRepository = UserPreferencesRepository()) {
        self.getLibraryItems = GetLibraryItems(repository: repositories.recurringItems)
        self.preferences = preferences
    }

    // MARK: - Actions

    func load() {
        error = nil
        do {
            defaultCurrency = preferences.load().defaultCurrencyCode
            allItems = try getLibraryItems.execute()
            isLoaded = true
        } catch {
            self.error = error
        }
    }

    // MARK: - Filtered & Sorted Output

    var filteredItems: [RecurringItem] {
        var result = allItems

        // 1. Status filter
        result = activeFilter.apply(to: result)

        // 2. Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                item.title.lowercased().contains(query)
                || item.providerName.lowercased().contains(query)
                || item.category.displayName.lowercased().contains(query)
                || item.note.lowercased().contains(query)
            }
        }

        // 3. Sort
        result = sortOrder.apply(to: result)

        return result
    }

    /// Counts per status filter — used for badges on chips.
    var filterCounts: [StatusFilter: Int] {
        var counts: [StatusFilter: Int] = [.all: allItems.count]
        for filter in StatusFilter.allCases where filter != .all {
            counts[filter] = filter.apply(to: allItems).count
        }
        return counts
    }

    /// Categories present in the current dataset for the category breakdown.
    var activeCategories: [ItemCategory] {
        let cats = Set(filteredItems.map(\.category))
        return ItemCategory.allCases.filter { cats.contains($0) }
    }

    /// Monthly total of currently filtered items.
    var filteredMonthlyTotal: Decimal {
        filteredItems
            .filter(\.status.countsInTotals)
            .reduce(Decimal.zero) { $0 + $1.monthlyEquivalent }
    }
}

// MARK: - Status Filter

extension LibraryViewModel {
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case trial
        case paused
        case cancelled
        case archived

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:       String(localized: "Все")
            case .active:    String(localized: "Активные")
            case .trial:     String(localized: "Пробные")
            case .paused:    String(localized: "Пауза")
            case .cancelled: String(localized: "Отменённые")
            case .archived:  String(localized: "Архив")
            }
        }

        var icon: String? {
            switch self {
            case .all:       nil
            case .active:    "checkmark.circle"
            case .trial:     "clock"
            case .paused:    "pause.circle"
            case .cancelled: "xmark.circle"
            case .archived:  "archivebox"
            }
        }

        func apply(to items: [RecurringItem]) -> [RecurringItem] {
            switch self {
            case .all:
                return items.filter { $0.status != .archived }
            case .active:
                return items.filter {
                    [.active, .dueSoon, .dueToday, .overdue, .failed].contains($0.status)
                }
            case .trial:
                return items.filter { $0.status == .trial }
            case .paused:
                return items.filter { $0.status == .paused }
            case .cancelled:
                return items.filter { $0.status == .cancelled }
            case .archived:
                return items.filter { $0.status == .archived }
            }
        }
    }
}

// MARK: - Sort Order

extension LibraryViewModel {
    enum SortOrder: String, CaseIterable, Identifiable {
        case nextCharge
        case name
        case amountAsc
        case amountDesc
        case recentlyAdded

        var id: String { rawValue }

        var title: String {
            switch self {
            case .nextCharge:   String(localized: "По дате списания")
            case .name:         String(localized: "По названию")
            case .amountAsc:    String(localized: "По цене ↑")
            case .amountDesc:   String(localized: "По цене ↓")
            case .recentlyAdded: String(localized: "Недавно добавленные")
            }
        }

        var icon: String {
            switch self {
            case .nextCharge:   "calendar.badge.clock"
            case .name:         "textformat.abc"
            case .amountAsc:    "arrow.up"
            case .amountDesc:   "arrow.down"
            case .recentlyAdded: "clock.arrow.circlepath"
            }
        }

        func apply(to items: [RecurringItem]) -> [RecurringItem] {
            switch self {
            case .nextCharge:
                return items.sorted { $0.nextChargeDate < $1.nextChargeDate }
            case .name:
                return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .amountAsc:
                return items.sorted { $0.monthlyEquivalent < $1.monthlyEquivalent }
            case .amountDesc:
                return items.sorted { $0.monthlyEquivalent > $1.monthlyEquivalent }
            case .recentlyAdded:
                return items.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }
}

