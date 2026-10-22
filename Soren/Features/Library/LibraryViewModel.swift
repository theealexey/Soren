import Foundation

// MARK: - Library View Model

/// Drives the Library screen with search, filtering, and sorting.
/// All filtering and sorting happens in-memory on the fetched dataset
/// via computed properties — @Observable triggers re-render automatically.
@MainActor @Observable
final class LibraryViewModel {

    // MARK: - User Input State (trigger recompute on change)

    var searchText: String = "" {
        didSet { if oldValue != searchText { scheduleSearch() } }
    }
    var activeFilter: StatusFilter = .all {
        didSet { if oldValue != activeFilter { cancelPendingSearch(); recompute() } }
    }
    var sortOrder: SortOrder = .nextCharge {
        didSet { if oldValue != sortOrder { cancelPendingSearch(); recompute() } }
    }

    // MARK: - Data State

    private(set) var allItems: [RecurringItem] = []
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var error: Error?
    private(set) var failedAction: FailedAction?
    private(set) var isLoaded = false
    /// Re-runs the single snapshot-loading task only when the current filtered
    /// total starts requiring FX without a usable snapshot.
    private(set) var aggregationRevision = 0

    // MARK: - Filtered Output (stored — computed once per state change, not per render)

    private(set) var filteredItems: [RecurringItem] = []
    private(set) var filterCounts: [StatusFilter: Int] = [:]
    private(set) var filteredMonthlyAggregation: RecurringSpendAggregationResult?
    private(set) var normalizationError: Error?
    private(set) var normalizationErrors: [UUID: Error] = [:]
    private(set) var activeCategories: [ItemCategory] = []
    private(set) var sections: [LibrarySection] = []

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getLibraryItems: GetLibraryItems
    private let deleteRecurringItem: DeleteRecurringItem
    private let preferences: UserPreferencesRepository
    private let exchangeRateProvider: any ExchangeRateProvider
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let convertMoney: ConvertMoneyUseCase
    private let searchDebounceDelay: Duration
    private let now: () -> Date
    private let timeZone: () -> TimeZone
    private(set) var today: CivilDate?

    /// One snapshot is shared by every total in the current Library calculation.
    /// A failed fetch deliberately leaves this nil: the Domain use case then emits
    /// partial/unavailable instead of constructing a mixed-currency number.
    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var inFlightAggregationRevision: Int?
    private var filteredMonthlyProjections: [RecurringSpendProjection] = []

    private static let aggregationRange = Date.distantPast..<Date.distantFuture

    // MARK: - Search Debounce

    private var searchTask: Task<Void, Never>?

    /// Cancels the previous pending search task and schedules a fresh recompute
    /// after `searchDebounceDelay`. Rapid keystrokes collapse into a single pass.
    private func scheduleSearch() {
        searchTask?.cancel()
        let delay = searchDebounceDelay
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.recompute()
        }
    }

    /// Cancels any pending debounced search task. Called when filter or sort
    /// changes so those immediate recomputes include the current searchText.
    private func cancelPendingSearch() {
        searchTask?.cancel()
        searchTask = nil
    }

    // MARK: - Init

    init(
        getLibraryItems: GetLibraryItems,
        deleteRecurringItem: DeleteRecurringItem,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        convertMoney: ConvertMoneyUseCase = ConvertMoneyUseCase(),
        searchDebounceDelay: Duration = .milliseconds(150),
        now: @escaping () -> Date = { .now },
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.getLibraryItems = getLibraryItems
        self.deleteRecurringItem = deleteRecurringItem
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.convertMoney = convertMoney
        self.searchDebounceDelay = searchDebounceDelay
        self.now = now
        self.timeZone = timeZone
    }

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        notificationCoordinator: (any NotificationStateReconciling)? = nil,
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        convertMoney: ConvertMoneyUseCase = ConvertMoneyUseCase(),
        searchDebounceDelay: Duration = .milliseconds(150),
        now: @escaping () -> Date = { .now },
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.getLibraryItems = GetLibraryItems(repository: repositories.recurringItems)
        self.deleteRecurringItem = DeleteRecurringItem(
            repository: repositories.recurringItems,
            notificationCoordinator: notificationCoordinator
        )
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.convertMoney = convertMoney
        self.searchDebounceDelay = searchDebounceDelay
        self.now = now
        self.timeZone = timeZone
    }

    // MARK: - Actions

    func load() {
        error = nil
        failedAction = nil
        aggregationRevision += 1
        exchangeRateSnapshot = nil
        do {
            defaultCurrency = preferences.load().defaultCurrencyCode
            allItems = try getLibraryItems.execute()
            isLoaded = true
            filteredMonthlyProjections = []
            recompute(scheduleSnapshotIfNeeded: false)
        } catch {
            self.error = error
            failedAction = .load
        }
    }

    /// Fetches at most one exchange-rate snapshot for the active Library revision.
    /// Older requests cannot overwrite a newer filter/data calculation.
    func refreshCurrencyAggregation(revision: Int) async {
        guard revision == aggregationRevision,
              exchangeRateSnapshot == nil,
              currentCalculationRequiresExchangeRates(),
              inFlightAggregationRevision != revision
        else { return }

        inFlightAggregationRevision = revision
        defer {
            if inFlightAggregationRevision == revision {
                inFlightAggregationRevision = nil
            }
        }

        do {
            let snapshot = try await exchangeRateProvider.latestSnapshot()
            guard !Task.isCancelled, revision == aggregationRevision else { return }
            exchangeRateSnapshot = snapshot
            // The same snapshot drives both the total and amount-sort projection.
            // Recompute synchronously so rows cannot retain their pre-FX order.
            recompute(scheduleSnapshotIfNeeded: false)
        } catch is CancellationError {
            return
        } catch {
            // The no-snapshot aggregation is already truthful: it never mixes
            // original foreign amounts into the reporting-currency subtotal.
        }
    }

    /// Deletes `item`, then updates the in-memory collection after persistence succeeds.
    /// A failed delete leaves the unchanged collection visible and records the failed action
    /// so Presentation can distinguish it from a load failure.
    @discardableResult
    func deleteItem(_ item: RecurringItem) async -> Bool {
        error = nil
        failedAction = nil
        do {
            try await deleteRecurringItem.execute(id: item.id)
            allItems.removeAll { $0.id == item.id }
            recompute()
            return true
        } catch {
            self.error = error
            failedAction = .delete(itemID: item.id)
            return false
        }
    }

    func dismissError() {
        error = nil
        failedAction = nil
    }

    // MARK: - Recompute (single pass — O(n log n) once per state change, not per render)

    private func recompute(scheduleSnapshotIfNeeded: Bool = true) {
        do {
            let today = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
            self.today = today
            try recompute(on: today, scheduleSnapshotIfNeeded: scheduleSnapshotIfNeeded)
        } catch {
            self.error = error
            failedAction = .load
        }
    }

    private func recompute(on today: CivilDate, scheduleSnapshotIfNeeded: Bool) throws {
        let previouslyRequiredRates = currentCalculationRequiresExchangeRates()
        normalizationErrors = [:]
        normalizationError = nil

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
        result = try sortItems(result, today: today)
        filteredItems = result

        // 3. Monthly total and active categories derived from the filtered result.
        // Existing Library semantics include only the statuses that historically
        // contributed to totals; aggregation itself is now the shared Domain policy.
        do {
            filteredMonthlyProjections = try result
                .filter { try $0.status.countsInTotals && !$0.isExpired(on: today) }
                .map { item in
                    RecurringSpendProjection(
                        date: item.nextChargeDate,
                        amount: try item.monthlyEquivalent,
                        currencyCode: item.currencyCode
                    )
                }
            rebuildMonthlyAggregation(snapshot: exchangeRateSnapshot)
        } catch {
            normalizationError = error
            filteredMonthlyProjections = []
            filteredMonthlyAggregation = nil
        }

        if scheduleSnapshotIfNeeded,
           exchangeRateSnapshot == nil,
           !previouslyRequiredRates,
           currentCalculationRequiresExchangeRates() {
            aggregationRevision += 1
        }

        let cats = Set(result.map(\.category))
        activeCategories = ItemCategory.allCases.filter { cats.contains($0) }

        // 4. Sections — computed once per state change, not per render.
        //
        // When the user views all items without a search query, items are grouped into
        // up to three named sections: active, past (expired finite subs), and archived.
        // All other filter/search combinations produce a single unnamed section so the
        // flat-list layout is preserved.
        if activeFilter == .all, searchText.isEmpty {
            let current  = try result.filter { try !$0.isExpired(on: today) }
            let past     = try result.filter { try $0.isExpired(on: today) }
            let archived = try sortItems(allItems.filter { $0.status == .archived }, today: today)

            let hasMixed = !past.isEmpty || !archived.isEmpty
            var built: [LibrarySection] = []
            if !current.isEmpty {
                built.append(LibrarySection(
                    id: "current",
                    title: hasMixed ? String(localized: "Текущие") : nil,
                    items: current
                ))
            }
            if !past.isEmpty {
                built.append(LibrarySection(id: "past", title: String(localized: "Завершённые"), items: past))
            }
            if !archived.isEmpty {
                built.append(LibrarySection(id: "archived", title: String(localized: "Архив"), items: archived))
            }
            sections = built.isEmpty ? [LibrarySection(id: "empty", title: nil, items: [])] : built
        } else {
            sections = [LibrarySection(id: "main", title: nil, items: result)]
        }
    }

    private func rebuildMonthlyAggregation(snapshot: ExchangeRateSnapshot?) {
        filteredMonthlyAggregation = aggregateRecurringSpend.execute(
            projections: filteredMonthlyProjections,
            reportingCurrencyCode: defaultCurrency,
            snapshot: snapshot,
            range: Self.aggregationRange
        )
    }

    private func currentCalculationRequiresExchangeRates() -> Bool {
        aggregateRecurringSpend.requiresExchangeRates(
            projections: filteredMonthlyProjections,
            reportingCurrencyCode: defaultCurrency,
            range: Self.aggregationRange
        )
    }

    // MARK: - Amount Sorting

    /// Produces monthly values in the current reporting currency before sorting.
    /// Unknown conversions deliberately remain unavailable instead of falling back
    /// to a raw amount from another currency.
    private func sortItems(_ items: [RecurringItem], today: CivilDate) throws -> [RecurringItem] {
        guard sortOrder.isAmountBased else {
            return try sortOrder.apply(to: items, today: today)
        }

        var sortKeys: [UUID: MonthlyAmountSortKey] = [:]
        for item in items {
            sortKeys[item.id] = monthlyAmountSortKey(for: item)
        }

        return items.sorted { lhs, rhs in
            let lhsKey = sortKeys[lhs.id] ?? .unavailable
            let rhsKey = sortKeys[rhs.id] ?? .unavailable
            return compareAmountSortKeys(lhsKey, rhsKey, lhs: lhs, rhs: rhs)
        }
    }

    private func monthlyAmountSortKey(for item: RecurringItem) -> MonthlyAmountSortKey {
        let amount: Decimal
        do {
            amount = try item.monthlyEquivalent
        } catch {
            normalizationErrors[item.id] = error
            return .unavailable
        }
        guard let reportingCurrencyCode = try? Money.normalizeCurrencyCode(defaultCurrency),
              let monthlyMoney = try? Money(
                  amount: amount,
                  currencyCode: item.currencyCode
              )
        else {
            return .unavailable
        }

        if monthlyMoney.currencyCode == reportingCurrencyCode {
            return .comparable(monthlyMoney.amount)
        }

        guard let exchangeRateSnapshot,
              let conversion = try? convertMoney.execute(
                  original: monthlyMoney,
                  targetCurrencyCode: reportingCurrencyCode,
                  snapshot: exchangeRateSnapshot
              )
        else {
            return .unavailable
        }

        return .comparable(conversion.converted.amount)
    }

    private func compareAmountSortKeys(
        _ lhsKey: MonthlyAmountSortKey,
        _ rhsKey: MonthlyAmountSortKey,
        lhs: RecurringItem,
        rhs: RecurringItem
    ) -> Bool {
        switch (lhsKey, rhsKey) {
        case let (.comparable(lhsValue), .comparable(rhsValue)):
            if lhsValue != rhsValue {
                return sortOrder == .amountAsc ? lhsValue < rhsValue : lhsValue > rhsValue
            }
            return hasDeterministicTieBreak(lhs, before: rhs)
        case (.comparable, .unavailable):
            return true
        case (.unavailable, .comparable):
            return false
        case (.unavailable, .unavailable):
            return hasDeterministicTieBreak(lhs, before: rhs)
        }
    }

    private func hasDeterministicTieBreak(_ lhs: RecurringItem, before rhs: RecurringItem) -> Bool {
        let titleOrder = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleOrder != .orderedSame {
            return titleOrder == .orderedAscending
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private enum MonthlyAmountSortKey {
    case comparable(Decimal)
    case unavailable
}

// MARK: - Library Section

extension LibraryViewModel {
    enum FailedAction: Equatable {
        case load
        case delete(itemID: UUID)
    }

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

        var isAmountBased: Bool {
            switch self {
            case .amountAsc, .amountDesc:
                true
            case .nextCharge, .name, .recentlyAdded:
                false
            }
        }

        var title: String {
            switch self {
            case .nextCharge:   String(localized: "По дате списания")
            case .name:         String(localized: "По названию")
            case .amountAsc:    String(localized: "По цене ↑")
            case .amountDesc:   String(localized: "По цене ↓")
            case .recentlyAdded: String(localized: "Недавно добавленные")
            }
        }

        var shortTitle: String {
            switch self {
            case .nextCharge:    String(localized: "По дате")
            case .name:          String(localized: "По названию")
            case .amountAsc:     String(localized: "Цена ↑")
            case .amountDesc:    String(localized: "Цена ↓")
            case .recentlyAdded: String(localized: "Недавние")
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

        func apply(to items: [RecurringItem], today: CivilDate) throws -> [RecurringItem] {
            switch self {
            case .nextCharge:
                return try items.sorted {
                    try $0.effectiveNextChargeDate(relativeTo: today) < $1.effectiveNextChargeDate(relativeTo: today)
                }
            case .name:
                return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .amountAsc, .amountDesc:
                // Amount sorting requires reporting-currency projections built by
                // LibraryViewModel; raw monthly values are not cross-currency keys.
                return items
            case .recentlyAdded:
                return items.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }
}
