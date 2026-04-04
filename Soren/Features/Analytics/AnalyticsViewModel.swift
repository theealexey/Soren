import Foundation

// MARK: - Category Spend

/// Aggregated monthly spend for one category, normalized to defaultCurrency.
struct CategorySpend: Identifiable {
    let category: ItemCategory
    let monthlyTotal: Decimal   // in defaultCurrency
    let itemCount: Int
    /// Share of grand monthly total: 0.0 – 1.0.
    let proportion: Double

    var id: String { category.rawValue }
}

// MARK: - Analytics View Model

/// Drives the Insights/Analytics tab.
///
/// Computes spending breakdown by category, top subscriptions by cost,
/// annual items to watch, and potentially-unused waste candidates.
/// Exchange rates are fetched async for cross-currency totals.
@MainActor @Observable
final class AnalyticsViewModel {

    // MARK: - State

    private(set) var summary: DashboardSummary = .empty
    private(set) var categoryBreakdown: [CategorySpend] = []
    private(set) var topItems: [RecurringItem] = []     // top 5 by monthly equivalent
    private(set) var annualItems: [RecurringItem] = []  // annual billing cycle
    private(set) var unusedItems: [RecurringItem] = []  // usageStatus == .unused
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var exchangeRates: ExchangeRates?
    private(set) var isLoaded = false
    private(set) var error: Error?

    /// Total monthly spend of all unused items — the "waste" figure.
    var unusedMonthlyCost: Decimal {
        unusedItems.reduce(.zero) { $0 + monthlyAmount($1) }
    }

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let repository: any RecurringItemRepository
    private let preferences: UserPreferencesRepository
    private let exchangeRateProvider: (any ExchangeRateProvider)?

    // MARK: - Init

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: (any ExchangeRateProvider)? = nil
    ) {
        let repo = repositories.recurringItems
        self.getDashboardSummary = GetDashboardSummary(repository: repo)
        self.repository = repo
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
    }

    // MARK: - Load

    func load(forceReload: Bool = false) async {
        guard !isLoaded || forceReload else { return }
        defaultCurrency = preferences.load().defaultCurrencyCode

        if let provider = exchangeRateProvider {
            if let rates = try? await provider.latestRates() {
                exchangeRates = rates
            }
        }

        loadLocalData(forceReload: forceReload)
    }

    /// Re-computes from persisted data without re-fetching exchange rates.
    /// Used by itemsVersion onChange to pick up newly added/removed items.
    func loadLocalData(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        error = nil
        do {
            let items = try repository.fetchActive()
            summary = try getDashboardSummary.execute(
                targetCurrency: defaultCurrency,
                rates: exchangeRates
            )
            categoryBreakdown = buildCategoryBreakdown(items)
            topItems = Array(
                items.sorted { monthlyAmount($0) > monthlyAmount($1) }.prefix(5)
            )
            annualItems = items.filter {
                if case .annual = $0.billingCycle { return true }
                return false
            }
            unusedItems = items.filter { $0.usageStatus == .unused }
            isLoaded = true
        } catch {
            self.error = error
        }
    }

    // MARK: - Private

    /// Monthly amount in defaultCurrency, converting via exchange rates when available.
    func monthlyAmount(_ item: RecurringItem) -> Decimal {
        guard let rates = exchangeRates, item.currencyCode != defaultCurrency else {
            return item.monthlyEquivalent
        }
        return rates.convert(item.monthlyEquivalent, from: item.currencyCode, to: defaultCurrency)
            ?? item.monthlyEquivalent
    }

    private func buildCategoryBreakdown(_ items: [RecurringItem]) -> [CategorySpend] {
        var totals: [ItemCategory: (Decimal, Int)] = [:]
        for item in items {
            let amount = monthlyAmount(item)
            let existing = totals[item.category] ?? (.zero, 0)
            totals[item.category] = (existing.0 + amount, existing.1 + 1)
        }

        let grandTotal = totals.values.reduce(.zero) { $0 + $1.0 }
        guard grandTotal > 0 else { return [] }

        return totals
            .map { category, data in
                CategorySpend(
                    category: category,
                    monthlyTotal: data.0,
                    itemCount: data.1,
                    proportion: NSDecimalNumber(decimal: data.0 / grandTotal).doubleValue
                )
            }
            .sorted { $0.monthlyTotal > $1.monthlyTotal }
    }
}
