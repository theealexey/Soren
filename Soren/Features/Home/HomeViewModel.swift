import SwiftUI

// MARK: - Home View Model

/// Drives the Home / Dashboard screen.
/// Financial snapshot at top, then status-filtered subscription list below.
@MainActor @Observable
final class HomeViewModel {

    // MARK: - Filter State

    var activeFilter: HomeFilter = .all

    // MARK: - Data State

    private(set) var summary: DashboardSummary = .empty
    private(set) var allItems: [RecurringItem] = []
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var exchangeRates: ExchangeRates?
    private(set) var ratesLastUpdated: Date?
    private(set) var isRatesStale = false
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Computed — Filtered Items

    /// Live subscriptions only (active, trial, paused). Excludes archived/cancelled.
    private var liveItems: [RecurringItem] {
        let liveStatuses: Set<ItemStatus> = [.active, .dueSoon, .dueToday, .overdue, .failed, .trial, .paused]
        return allItems
            .filter { liveStatuses.contains($0.status) }
            .sorted { $0.nextChargeDate < $1.nextChargeDate }
    }

    var filteredItems: [RecurringItem] {
        activeFilter.apply(to: liveItems)
    }

    var filterCounts: [HomeFilter: Int] {
        var counts: [HomeFilter: Int] = [.all: liveItems.count]
        for filter in HomeFilter.allCases where filter != .all {
            counts[filter] = filter.apply(to: liveItems).count
        }
        return counts
    }

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let getLibraryItems: GetLibraryItems
    private let preferences: UserPreferencesRepository
    private let exchangeRateProvider: (any ExchangeRateProvider)?

    // MARK: - Init

    init(
        getDashboardSummary: GetDashboardSummary,
        getLibraryItems: GetLibraryItems,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: (any ExchangeRateProvider)? = nil
    ) {
        self.getDashboardSummary = getDashboardSummary
        self.getLibraryItems = getLibraryItems
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
    }

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: (any ExchangeRateProvider)? = nil
    ) {
        let repo = repositories.recurringItems
        self.getDashboardSummary = GetDashboardSummary(repository: repo)
        self.getLibraryItems = GetLibraryItems(repository: repo)
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
    }

    // MARK: - Actions

    func load(forceReload: Bool = false) async {
        if !isLoaded || forceReload, let provider = exchangeRateProvider {
            do {
                let rates = try await provider.latestRates()
                exchangeRates = rates
                ratesLastUpdated = rates.fetchedAt
                isRatesStale = false
            } catch {
                isRatesStale = true
            }
        }
        loadLocalData(forceReload: forceReload)
    }

    func loadLocalData(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        error = nil
        do {
            defaultCurrency = preferences.load().defaultCurrencyCode
            summary = try getDashboardSummary.execute(
                targetCurrency: defaultCurrency,
                rates: exchangeRates
            )
            allItems = try getLibraryItems.execute()
            isLoaded = true
        } catch {
            self.error = error
        }
    }
}

// MARK: - Insights

extension HomeViewModel {
    var insights: [InsightsBuilder.InsightData] {
        InsightsBuilder.build(from: liveItems)
    }
}

// MARK: - Home Filter

extension HomeViewModel {

    enum HomeFilter: String, CaseIterable, Identifiable {
        case all
        case active
        case trial
        case paused

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:    String(localized: "Все")
            case .active: String(localized: "Активные")
            case .trial:  String(localized: "Пробные")
            case .paused: String(localized: "Пауза")
            }
        }

        var icon: String? {
            switch self {
            case .all:    nil
            case .active: "checkmark.circle"
            case .trial:  "clock"
            case .paused: "pause.circle"
            }
        }

        func apply(to items: [RecurringItem]) -> [RecurringItem] {
            switch self {
            case .all:
                return items
            case .active:
                return items.filter { [.active, .dueSoon, .dueToday, .overdue, .failed].contains($0.status) }
            case .trial:
                return items.filter { $0.status == .trial }
            case .paused:
                return items.filter { $0.status == .paused }
            }
        }
    }
}
