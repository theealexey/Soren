import Foundation

// MARK: - Monthly Projection

/// Projected total spend for a single calendar month, in defaultCurrency.
struct MonthlyProjection: Identifiable {
    let month: Date        // first day of the month
    let total: Decimal
    var id: Date { month }

    /// Short month label for chart axis (e.g. "Апр").
    var shortLabel: String {
        Self.labelFormatter.string(from: month)
    }

    /// `Decimal → Double` bridge — only for chart rendering.
    var doubleTotal: Double {
        NSDecimalNumber(decimal: total).doubleValue
    }

    private static let labelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "MMM"
        return f
    }()
}

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
    private(set) var monthlyProjections: [MonthlyProjection] = []
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
            monthlyProjections = buildProjections(items)
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

    private func buildProjections(_ items: [RecurringItem], months: Int = 6) -> [MonthlyProjection] {
        let cal = Calendar.current
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: .now)) else { return [] }

        return (0..<months).compactMap { offset in
            guard let start = cal.date(byAdding: .month, value: offset, to: monthStart),
                  let end   = cal.date(byAdding: .month, value: 1, to: start) else { return nil }

            let total = items.reduce(Decimal.zero) { sum, item in
                sum + projectedAmount(item, from: start, to: end)
            }
            return MonthlyProjection(month: start, total: total)
        }
    }

    /// Amount this item contributes to a specific calendar month.
    ///
    /// - Monthly/weekly/custom: `monthlyEquivalent` every month (smooth).
    /// - Long-cycle (quarterly, semiannual, annual): full `amount` only in months
    ///   where a charge actually lands; zero otherwise.
    private func projectedAmount(_ item: RecurringItem, from start: Date, to end: Date) -> Decimal {
        if item.billingCycle.isLongCycle {
            return hasCharge(item, from: start, to: end) ? convertedAmount(item) : .zero
        }
        return monthlyAmount(item)
    }

    /// Returns true if a billing cycle iteration of `item` falls within [start, end).
    private func hasCharge(_ item: RecurringItem, from start: Date, to end: Date) -> Bool {
        let cal = Calendar.current
        let cycleMonths: Int
        switch item.billingCycle {
        case .quarterly:  cycleMonths = 3
        case .semiannual: cycleMonths = 6
        case .annual:     cycleMonths = 12
        default:          return true
        }

        // Walk nextChargeDate backward until it's before `start`
        var check = item.nextChargeDate
        while check >= end {
            guard let prev = cal.date(byAdding: .month, value: -cycleMonths, to: check) else { return false }
            check = prev
        }
        // Then walk forward until it's >= start or past end
        while check < start {
            guard let next = cal.date(byAdding: .month, value: cycleMonths, to: check) else { return false }
            check = next
        }
        return check >= start && check < end
    }

    /// Actual item amount converted to defaultCurrency (used for long-cycle charges).
    private func convertedAmount(_ item: RecurringItem) -> Decimal {
        guard let rates = exchangeRates, item.currencyCode != defaultCurrency else {
            return item.amount
        }
        return rates.convert(item.amount, from: item.currencyCode, to: defaultCurrency) ?? item.amount
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
