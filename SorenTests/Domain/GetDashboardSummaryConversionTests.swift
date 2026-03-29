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

    private func makeRepo() throws -> SwiftDataRecurringItemRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataRecurringItemRepository(context: container.mainContext)
    }

    private let rates = ExchangeRates(
        base: "USD",
        date: .now,
        rates: ["RUB": 87.5, "EUR": 0.92, "GBP": 0.79, "TRY": 38.2],
        fetchedAt: .now
    )

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

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

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

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        // $10 USD → RUB: 10 * 87.5 / 1 = 875
        // Total: 100 + 875 = 975
        let usdInRub = Decimal(10) * Decimal(string: "87.5")!
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

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        // EUR→RUB: 10 * 87.5 / 0.92
        let eurInRub = Decimal(10) * Decimal(string: "87.5")! / Decimal(string: "0.92")!
        // GBP→RUB: 5 * 87.5 / 0.79
        let gbpInRub = Decimal(5) * Decimal(string: "87.5")! / Decimal(string: "0.79")!

        #expect(summary.monthlyTotal == 500 + eurInRub + gbpInRub)
        #expect(summary.containsMixedCurrencies)
    }

    // MARK: - Mixed Currency + No Rates

    @Test("Mixed currencies without rates falls back to raw sum")
    func mixedNoRates() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "USD"))

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: nil)

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

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: .empty)

        #expect(summary.monthlyTotal == 110)
        #expect(!summary.ratesAvailable)
    }

    // MARK: - Unknown Currency Fallback

    @Test("Unknown currency falls back to raw amount without crash")
    func unknownCurrency() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 50, currency: "XYZ"))  // Not in rates

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        // XYZ can't convert → falls back to raw 50
        // Total: 100 (RUB converted = 100) + 50 (raw)
        #expect(summary.monthlyTotal == 150)
        #expect(summary.containsMixedCurrencies)
    }

    // MARK: - Same Currency Despite Having Rates

    @Test("All same currency skips conversion even when rates provided")
    func sameCurrencyWithRates() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "USD"))
        try repo.save(makeItem(amount: 200, currency: "USD"))

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "USD", rates: rates)

        // No conversion needed — all USD
        #expect(summary.monthlyTotal == 300)
        #expect(!summary.containsMixedCurrencies)
    }

    // MARK: - Yearly Invariant

    @Test("yearlyProjection is always monthlyTotal * 12")
    func yearlyInvariant() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(amount: 100, currency: "RUB"))
        try repo.save(makeItem(amount: 10, currency: "EUR"))

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        #expect(summary.yearlyProjection == summary.monthlyTotal * 12)
    }

    // MARK: - Empty State

    @Test("Zero items returns empty summary")
    func emptyState() throws {
        let repo = try makeRepo()
        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        #expect(summary == .empty)
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

        let summary = try GetDashboardSummary(repository: repo)
            .execute(targetCurrency: "RUB", rates: rates)

        #expect(summary.monthlyTotal == 500)
        #expect(summary.activeTrialCount == 1)
        #expect(summary.activeItemCount == 1)
    }
}
