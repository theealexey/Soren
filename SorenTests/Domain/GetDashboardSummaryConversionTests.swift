import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Dashboard Summary Currency Conversion Tests (Adversarial)

/// Focuses on the multi-currency conversion path in GetDashboardSummary.
/// The happy-path (single currency, no rates) is already covered in HomeViewModelTests.

@Suite("GetDashboardSummary — Currency Conversion")
@MainActor
struct GetDashboardSummaryConversionTests {

    @MainActor
    private struct Fixture {
        private static let posixLocale = Locale(identifier: "en_US_POSIX")

        let persistence: InMemoryPersistenceFixture
        let repository: SwiftDataRecurringItemRepository
        let rates: ExchangeRates

        init() throws {
            let persistence = try InMemoryPersistenceFixture()
            self.persistence = persistence
            self.repository = persistence.recurringItems
            self.rates = ExchangeRates(
                base: "USD",
                date: .now,
                rates: [
                    "RUB": try Self.decimal("87.5"),
                    "EUR": try Self.decimal("0.92"),
                    "GBP": try Self.decimal("0.79"),
                    "TRY": try Self.decimal("38.2")
                ],
                fetchedAt: .now
            )
        }

        func save(_ item: RecurringItem) throws {
            try repository.save(item)
        }

        func fetchActive() throws -> [RecurringItem] {
            try repository.fetchActive()
        }

        func decimal(_ value: String) throws -> Decimal {
            try Self.decimal(value)
        }

        private static func decimal(_ value: String) throws -> Decimal {
            try #require(Decimal(string: value, locale: posixLocale))
        }
    }

    private func makeRepo() throws -> Fixture {
        try Fixture()
    }

    private func makeItem(
        amount: Decimal,
        currency: String = "RUB",
        status: ItemStatus = .active
    ) -> RecurringItem {
        RecurringItem(
            title: "Test \(currency)",
            amount: amount,
            currencyCode: currency,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            status: status
        )
    }

    // MARK: - Single Currency

    @Test("Single currency skips conversion, containsMixedCurrencies is false")
    func singleCurrency() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 200, currency: "RUB"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        #expect(summary.monthlyTotal == 300)
        #expect(!summary.containsMixedCurrencies)
    }

    // MARK: - Mixed Currency + Rates

    @Test("Mixed currencies with rates converts to target correctly")
    func mixedWithRates() throws {
        let repo = try makeRepo()
        // 100 RUB/month + $10 USD/month, target = RUB
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "USD"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        // $10 USD → RUB: 10 * 87.5 / 1 = 875
        // Total: 100 + 875 = 975
        let usdInRub = Decimal(10) * (try repo.decimal("87.5"))
        #expect(summary.monthlyTotal == 100 + usdInRub)
        #expect(summary.containsMixedCurrencies)
        #expect(summary.ratesAvailable)
    }

    @Test("Three currencies all convert to RUB")
    func threeCurrencies() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 500, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "EUR"))
        try repo.save(makeItem(amount: 5, currency: "GBP"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        // EUR→RUB: 10 * 87.5 / 0.92
        let eurInRub = Decimal(10) * (try repo.decimal("87.5")) / (try repo.decimal("0.92"))
        // GBP→RUB: 5 * 87.5 / 0.79
        let gbpInRub = Decimal(5) * (try repo.decimal("87.5")) / (try repo.decimal("0.79"))

        #expect(summary.monthlyTotal == 500 + eurInRub + gbpInRub)
        #expect(summary.containsMixedCurrencies)
    }

    // MARK: - Mixed Currency + No Rates

    @Test("Mixed currencies without rates falls back to raw sum")
    func mixedNoRates() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "USD"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: nil)

        // Raw sum: 100 + 10 = 110 (meaningless but safe)
        #expect(summary.monthlyTotal == 110)
        #expect(summary.containsMixedCurrencies)
        #expect(!summary.ratesAvailable)
    }

    @Test("Mixed currencies with .empty rates falls back to raw sum")
    func mixedEmptyRates() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "USD"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: .empty)

        #expect(summary.monthlyTotal == 110)
        #expect(!summary.ratesAvailable)
    }

    // MARK: - Unknown Currency Fallback

    @Test("Unknown currency falls back to raw amount without crash")
    func unknownCurrency() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 50, currency: "XYZ"))  // Not in rates

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        // XYZ can't convert → falls back to raw 50
        // Total: 100 (RUB no conversion needed) + 50 (raw fallback)
        #expect(summary.monthlyTotal == 150)
        #expect(summary.containsMixedCurrencies)
    }

    // MARK: - Same Currency Despite Having Rates

    @Test("All same currency skips conversion even when rates provided")
    func sameCurrencyWithRates() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "USD"))
        try repo.save(makeItem(amount: 200, currency: "USD"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "USD", rates: repo.rates)

        // No conversion needed — all USD
        #expect(summary.monthlyTotal == 300)
        #expect(!summary.containsMixedCurrencies)
    }

    @Test("Single currency different from target converts correctly")
    func singleCurrencyDifferentFromTarget() throws {
        let repo = try makeRepo()
        // Both subscriptions in USD, display currency is EUR
        try repo.save(makeItem(amount: 10, currency: "USD"))
        try repo.save(makeItem(amount: 20, currency: "USD"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "EUR", rates: repo.rates)

        // 30 USD → EUR: 30 * 0.92 / 1 = 27.6
        let expected = Decimal(30) * (try repo.decimal("0.92"))
        #expect(summary.monthlyTotal == expected)
        #expect(!summary.containsMixedCurrencies)
        #expect(summary.ratesAvailable)
    }

    // MARK: - Yearly Invariant

    @Test("yearlyProjection is always monthlyTotal * 12")
    func yearlyInvariant() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "EUR"))

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        #expect(summary.yearlyProjection == summary.monthlyTotal * 12)
    }

    // MARK: - Empty State

    @Test("Zero items returns empty summary")
    func emptyState() throws {
        let repo = try makeRepo()
        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        #expect(summary.monthlyTotal == 0)
        #expect(summary.yearlyProjection == 0)
        #expect(summary.activeItemCount == 0)
        #expect(summary.activeTrialCount == 0)
        #expect(!summary.containsMixedCurrencies)
        #expect(summary.ratesAvailable)
    }

    // MARK: - Trial Items Counted

    @Test("Trial items included in monthlyTotal and trialCount")
    func trialsIncluded() throws {
        let repo = try makeRepo()

        let trial = RecurringItem(
            title: "Trial",
            amount: 500,
            currencyCode: "RUB",
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 14, to: .now),
            status: .trial
        )
        try repo.save(trial)

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items, targetCurrency: "RUB", rates: repo.rates)

        #expect(summary.monthlyTotal == 500)
        #expect(summary.activeTrialCount == 1)
        #expect(summary.activeItemCount == 1)
    }
}
