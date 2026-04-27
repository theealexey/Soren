import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Library Total Calculation Tests (Adversarial)

/// Focuses on the Library header total:
///   • Currency conversion (the primary bug — USD items were previously added raw)
///   • Status filtering (cancelled / paused must not contribute)
///   • Billing-cycle normalisation (annual amounts use monthlyMultiplier)
///   • Fallback behaviour when rates are unavailable

@Suite("LibraryViewModel — Total Calculation")
@MainActor
struct LibraryTotalTests {

    // MARK: - Fixtures

    private func makeVM(
        rates: ExchangeRates = .preview
    ) throws -> (LibraryViewModel, RepositoryContainer) {
        let mc    = try SorenModelContainer.inMemory()
        let repos = RepositoryContainer(context: mc.mainContext)
        let vm    = LibraryViewModel(
            repositories: repos,
            exchangeRateProvider: StaticExchangeRateProvider(rates: rates),
            searchDebounceDelay: .zero
        )
        return (vm, repos)
    }

    private func makeItem(
        title: String,
        amount: Decimal,
        currency: String,
        cycle: BillingCycle = .monthly,
        status: ItemStatus = .active
    ) -> RecurringItem {
        var item = RecurringItem(
            title: title,
            amount: amount,
            currencyCode: currency,
            billingCycle: cycle,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!
        )
        item.status = status
        return item
    }

    // MARK: - Single Currency (RUB)

    @Test("All-RUB items sum without conversion")
    func allRubItemsSumDirectly() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Boosty",    amount: 450, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "Кинопоиск", amount: 299, currency: "RUB"))
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 749)
    }

    // MARK: - Currency Conversion

    @Test("USD item is converted to RUB — not added as raw dollar value")
    func usdItemConvertsToRub() async throws {
        // .preview rates: 1 USD = 87.5 RUB
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Boosty",    amount: 450, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "X Premium", amount: 8,   currency: "USD"))
        vm.load()
        await Task.yield(); await Task.yield()

        let usdInRub = Decimal(8) * Decimal(string: "87.5")!   // 700 RUB
        let expected = Decimal(450) + usdInRub
        #expect(vm.filteredMonthlyTotal == expected,
                "8 USD at 87.5 = 700 RUB; expected total \(expected), got \(vm.filteredMonthlyTotal)")
    }

    @Test("Total is never polluted by raw USD value — $8/mo is not ₽8")
    func totalNotPolludedByRawDollarAmount() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "X Premium", amount: 8, currency: "USD"))
        vm.load()
        await Task.yield(); await Task.yield()

        // $8 → ~₽700 at preview rate. The old bug would produce total == 8.
        #expect(vm.filteredMonthlyTotal != 8,
                "Total should be the RUB equivalent (~700), not the raw USD integer 8")
        #expect(vm.filteredMonthlyTotal > 600,
                "8 USD at any reasonable RUB rate should exceed ₽600")
    }

    @Test("Three currencies all convert to RUB target")
    func threeCurrenciesAllConvert() async throws {
        // .preview: USD=87.5, EUR=0.92, TRY=38.2 (all relative to USD base)
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "RUB item", amount: 500, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "USD item", amount: 10,  currency: "USD"))
        try repos.recurringItems.save(makeItem(title: "TRY item", amount: 100, currency: "TRY"))
        vm.load()
        await Task.yield(); await Task.yield()

        // USD→RUB: 10 * 87.5 / 1 = 875
        let usdInRub  = Decimal(10)  * Decimal(string: "87.5")!
        // TRY→RUB: 100 * 87.5 / 38.2
        let tryInRub  = Decimal(100) * Decimal(string: "87.5")! / Decimal(string: "38.2")!
        let expected  = Decimal(500) + usdInRub + tryInRub

        #expect(vm.filteredMonthlyTotal == expected)
    }

    // MARK: - Rates Unavailable (Fallback)

    @Test("When no rates available, raw sum is used — consistent with Dashboard fallback")
    func noRatesFallsBackToRawSum() async throws {
        let (vm, repos) = try makeVM(rates: .empty)
        try repos.recurringItems.save(makeItem(title: "RUB", amount: 100, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "USD", amount: 10,  currency: "USD"))
        vm.load()
        await Task.yield(); await Task.yield()

        // Fallback: rates.convert returns nil → raw amounts used
        // 100 + 10 = 110 (meaningless but deterministic, not 0)
        #expect(vm.filteredMonthlyTotal == 110)
    }

    // MARK: - Billing Cycle Normalisation

    @Test("Annual item contributes its monthly equivalent, not full amount")
    func annualItemUsesMonthlyEquivalent() async throws {
        let (vm, repos) = try makeVM()
        // 1200 RUB/year × 0.0833 ≈ 99.96 RUB/month
        try repos.recurringItems.save(makeItem(title: "Annual", amount: 1200, currency: "RUB", cycle: .annual))
        vm.load()
        await Task.yield(); await Task.yield()

        let expected = Decimal(1200) * BillingCycle.annual.monthlyMultiplier
        #expect(vm.filteredMonthlyTotal == expected)
        #expect(vm.filteredMonthlyTotal < 200,
                "Annual ₽1200 = ~₽100/mo; total must not be the full ₽1200")
    }

    // MARK: - Status Filtering

    @Test("Cancelled items are excluded from total")
    func cancelledItemsExcluded() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Active",    amount: 500,  currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "Cancelled", amount: 1000, currency: "RUB", status: .cancelled))
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 500)
    }

    @Test("Paused items are excluded from total")
    func pausedItemsExcluded() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Active", amount: 300, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "Paused", amount: 900, currency: "RUB", status: .paused))
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 300)
    }

    @Test("Trial items ARE included in total")
    func trialItemsIncluded() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Active", amount: 400, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "Trial",  amount: 200, currency: "RUB", status: .trial))
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 600)
    }

    @Test("Archived items are excluded from total")
    func archivedItemsExcluded() async throws {
        let (vm, repos) = try makeVM()
        try repos.recurringItems.save(makeItem(title: "Active",   amount: 300, currency: "RUB"))
        try repos.recurringItems.save(makeItem(title: "Archived", amount: 900, currency: "RUB", status: .archived))
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 300)
    }

    // MARK: - Empty State

    @Test("Empty library produces zero total")
    func emptyLibraryZeroTotal() async throws {
        let (vm, repos) = try makeVM()
        _ = repos  // empty
        vm.load()
        await Task.yield(); await Task.yield()

        #expect(vm.filteredMonthlyTotal == 0)
    }
}
