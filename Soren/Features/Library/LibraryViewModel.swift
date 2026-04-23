import Foundation

// MARK: - Library View Model

/// Drives the Library screen with search, filtering, and sorting.
/// All filtering and sorting happens in-memory on the fetched dataset
/// via computed properties — @Observable triggers re-render automatically.
@MainActor @Observable
final class LibraryViewModel {

    // MARK: - User Input State (trigger recompute on change)

    var searchText: String = "" {
        didSet { if oldValue != searchText { recompute() } }
    }
    var activeFilter: StatusFilter = .all {
        didSet { if oldValue != activeFilter { recompute() } }
    }
    var sortOrder: SortOrder = .nextCharge {
        didSet { if oldValue != sortOrder { recompute() } }
    }

    // MARK: - Data State

    private(set) var allItems: [RecurringItem] = []
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var error: Error?
    private(set) var isLoaded = false

    // MARK: - Filtered Output (stored — computed once per state change, not per render)

    private(set) var filteredItems: [RecurringItem] = []
    private(set) var filterCounts: [StatusFilter: Int] = [:]
    private(set) var filteredMonthlyTotal: Decimal = .zero
    private(set) var activeCategories: [ItemCategory] = []

    var hasError: Bool { error != nil }

    // MARK: - Sectioned Output

    /// Structured sections for the Library list.
    ///
    /// When the user views all items without a search query, items are grouped into
    /// up to three named sections: active, past (expired finite subs), and archived.
    /// All other filter/search combinations return a single unnamed section so the
    /// existing flat-list layout is preserved.
    var sections: [LibrarySection] {
        guard activeFilter == .all, searchText.isEmpty else {
            return [LibrarySection(id: "main", title: nil, items: filteredItems)]
        }
        let active   = filteredItems.filter { !$0.isExpired }
        let past     = filteredItems.filter {  $0.isExpired }
        let archived = allItems.filter { $0.status == .archived }

        let hasMixed = !past.isEmpty || !archived.isEmpty
        var result: [LibrarySection] = []
        if !active.isEmpty {
            result.append(LibrarySection(
                id: "active",
                title: hasMixed ? String(localized: "Активные") : nil,
                items: active
            ))
        }
        if !past.isEmpty {
            result.append(LibrarySection(id: "past", title: String(localized: "Завершённые"), items: past))
        }
        if !archived.isEmpty {
            result.append(LibrarySection(id: "archived", title: String(localized: "Архив"), items: archived))
        }
        return result.isEmpty ? [LibrarySection(id: "empty", title: nil, items: [])] : result
    }

    // MARK: - Dependencies

    private let getLibraryItems: GetLibraryItems
    private let deleteRecurringItem: DeleteRecurringItem
    private let preferences: UserPreferencesRepository
    private let notificationScheduler: (any NotificationScheduling)?

    // MARK: - Init

    init(
        getLibraryItems: GetLibraryItems,
        deleteRecurringItem: DeleteRecurringItem,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.getLibraryItems = getLibraryItems
        self.deleteRecurringItem = deleteRecurringItem
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
    }

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.getLibraryItems = GetLibraryItems(repository: repositories.recurringItems)
        self.deleteRecurringItem = DeleteRecurringItem(repository: repositories.recurringItems)
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
    }

    // MARK: - Actions

    func load() {
        error = nil
        do {
            defaultCurrency = preferences.load().defaultCurrencyCode
            allItems = try getLibraryItems.execute()
            isLoaded = true
            recompute()
        } catch {
            self.error = error
        }
    }

    /// Deletes `item` from persistent storage and removes it from the local list immediately
    /// (optimistic update). The notification is cancelled fire-and-forget.
    /// On failure the error state is set and the list is reloaded to restore consistency.
    func deleteItem(_ item: RecurringItem) {
        do {
            try deleteRecurringItem.execute(id: item.id)
            allItems.removeAll { $0.id == item.id }
            recompute()
            if let scheduler = notificationScheduler {
                let itemID = item.id
                Task { await scheduler.cancel(for: itemID) }
            }
        } catch {
            self.error = error
            load()   // restore list state on unexpected failure
        }
    }

    // MARK: - Recompute (single pass — O(n log n) once per state change, not per render)

    private func recompute() {
        // 1. Filter counts: one pass per status filter over allItems.
        var counts: [StatusFilter: Int] = [.all: allItems.count]
        for filter in StatusFilter.allCases where filter != .all {
            counts[filter] = filter.apply(to: allItems).count
        }
        filterCounts = counts

        // 2. Filtered + searched + sorted items.
        var result = activeFilter.apply(to: allItems)
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { item in
                item.title.lowercased().contains(query)
                || item.providerName.lowercased().contains(query)
                || item.category.displayName.lowercased().contains(query)
                || item.note.lowercased().contains(query)
            }
        }
        result = sortOrder.apply(to: result)
        filteredItems = result

        // 3. Monthly total and active categories derived from the filtered result.
        filteredMonthlyTotal = result
            .filter(\.status.countsInTotals)
            .reduce(.zero) { $0 + $1.monthlyEquivalent }

        let cats = Set(result.map(\.category))
        activeCategories = ItemCategory.allCases.filter { cats.contains($0) }
    }
}

// MARK: - Library Section

extension LibraryViewModel {
    struct LibrarySection: Identifiable {
        let id: String
        let title: String?   // nil → no visible header
        let items: [RecurringItem]
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

