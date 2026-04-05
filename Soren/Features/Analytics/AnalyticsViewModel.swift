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
/// Loads a single [RecurringItem] snapshot and builds AnalyticsScreenState
/// atomically — all counts, totals and breakdowns derive from the same array.
/// Exchange rates are fetched async on first load and reused on item changes.
@MainActor @Observable
final class AnalyticsViewModel {

    // MARK: - State

    private(set) var screenState: AnalyticsScreenState = .empty
    private(set) var isLoaded = false
    private(set) var error: Error?

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let repository: any RecurringItemRepository
    private let preferences: UserPreferencesRepository
    private let exchangeRateProvider: (any ExchangeRateProvider)?

    // MARK: - Exchange rates — VM-internal, not exposed in screenState

    private var exchangeRates: ExchangeRates?
    private var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode

    // MARK: - Init

    init(
        repositories: RepositoryContainer,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: (any ExchangeRateProvider)? = nil
    ) {
        self.getDashboardSummary = GetDashboardSummary()
        self.repository = repositories.recurringItems
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

            let summary = getDashboardSummary.execute(
                items: items,
                targetCurrency: defaultCurrency,
                rates: exchangeRates
            )
            let unusedItems = items.filter { $0.usageStatus == .unused }
            let unusedCost = unusedItems.reduce(Decimal.zero) { $0 + monthlyAmount($1) }

            screenState = AnalyticsScreenState(
                summary: summary,
                categoryBreakdown: buildCategoryBreakdown(items),
                monthlyProjections: buildProjections(items),
                topItems: Array(items.sorted { monthlyAmount($0) > monthlyAmount($1) }.prefix(5)),
                annualItems: items.filter { if case .annual = $0.billingCycle { return true }; return false },
                unusedItems: unusedItems,
                defaultCurrency: defaultCurrency,
                unusedMonthlyCost: unusedCost
            )
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

    // Stored once to avoid unsafe Calendar.current access in async contexts.
    private static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = .current
        c.timeZone = .current
        return c
    }()

    private func buildProjections(_ items: [RecurringItem], months: Int = 6) -> [MonthlyProjection] {
        let cal = Self.cal
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
        let cal = Self.cal
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
