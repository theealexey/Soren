import SwiftUI

// MARK: - Home View Model

/// Drives the Overview screen.
/// Financial snapshot, upcoming charges, active trials, and quick insights.
@MainActor @Observable
final class HomeViewModel {

    // MARK: - State

    private(set) var summary: DashboardSummary = .empty
    private(set) var allItems: [RecurringItem] = []
    private(set) var upcomingCharges: [RecurringItem] = []
    private(set) var activeTrials: [RecurringItem] = []
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var exchangeRates: ExchangeRates?
    private(set) var ratesLastUpdated: Date?
    private(set) var isRatesStale = false
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let getLibraryItems: GetLibraryItems
    private let getUpcomingCharges: GetUpcomingCharges
    private let getActiveTrials: GetActiveTrials
    private let preferences: UserPreferencesRepository
    private let exchangeRateProvider: (any ExchangeRateProvider)?

    // MARK: - Init

    init(
        getDashboardSummary: GetDashboardSummary,
        getLibraryItems: GetLibraryItems,
        getUpcomingCharges: GetUpcomingCharges,
        getActiveTrials: GetActiveTrials,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: (any ExchangeRateProvider)? = nil
    ) {
        self.getDashboardSummary = getDashboardSummary
        self.getLibraryItems = getLibraryItems
        self.getUpcomingCharges = getUpcomingCharges
        self.getActiveTrials = getActiveTrials
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
        self.getUpcomingCharges = GetUpcomingCharges(repository: repo)
        self.getActiveTrials = GetActiveTrials(repository: repo)
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
            upcomingCharges = try getUpcomingCharges.execute()
            activeTrials = try getActiveTrials.execute()
            isLoaded = true
        } catch {
            self.error = error
        }
    }
}

// MARK: - Insights

extension HomeViewModel {
    var insights: [InsightsBuilder.InsightData] {
        InsightsBuilder.build(from: upcomingCharges)
    }
}
