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
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getLibraryItems: GetLibraryItems

    // MARK: - Init

    init(getLibraryItems: GetLibraryItems) {
        self.getLibraryItems = getLibraryItems
    }

    init(repositories: RepositoryContainer) {
        self.getLibraryItems = GetLibraryItems(repository: repositories.recurringItems)
    }

    // MARK: - Actions

    func load() {
        error = nil
        do {
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
            case .all:       "Все"
            case .active:    "Активные"
            case .trial:     "Пробные"
            case .paused:    "Пауза"
            case .cancelled: "Отменённые"
            case .archived:  "Архив"
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
            case .nextCharge:   "По дате списания"
            case .name:         "По названию"
            case .amountAsc:    "По цене ↑"
            case .amountDesc:   "По цене ↓"
            case .recentlyAdded: "Недавно добавленные"
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

// MARK: - Display Helpers

extension LibraryViewModel {

    static func cycleLabel(for cycle: BillingCycle) -> AmountLabel.CycleLabel {
        switch cycle {
        case .weekly:       .weekly
        case .monthly:      .monthly
        case .annual:       .yearly
        case .quarterly:    .custom("кв")
        case .semiannual:   .custom("п/г")
        case .custom(let d): .custom("\(d)д")
        }
    }

    static func badge(for item: RecurringItem) -> SorenListRow.Badge? {
        if item.isActiveTrial { return .trial }
        switch item.status {
        case .failed:   return .failed
        case .paused:   return .paused
        case .dueSoon, .dueToday:
            return .dueSoon
        case .cancelled: return nil
        default:
            return item.billingCycle.isLongCycle ? .annual : nil
        }
    }

    static func subtitle(for item: RecurringItem) -> String {
        switch item.status {
        case .cancelled:
            return "Отменена"
        case .paused:
            return "На паузе"
        case .archived:
            return "В архиве"
        default:
            let days = item.daysUntilNextCharge
            if days < 0 { return "Просрочено на \(abs(days)) дн." }
            if days == 0 { return "Списание сегодня" }
            if days == 1 { return "Списание завтра" }
            return "Списание через \(days) дн."
        }
    }
}
