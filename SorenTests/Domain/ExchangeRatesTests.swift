import Testing
import Foundation
@testable import Soren

// MARK: - Exchange Rates Conversion Tests (Adversarial)

/// Tries to break ExchangeRates.convert() with edge cases,
/// precision traps, and malformed inputs.

@Suite("ExchangeRates")
struct ExchangeRatesTests {

    private let rates = ExchangeRates(
        base: "USD",
        date: .now,
        rates: [
            "RUB": Decimal(string: "87.5")!,
            "EUR": Decimal(string: "0.92")!,
            "GBP": Decimal(string: "0.79")!,
            "TRY": Decimal(string: "38.2")!,
            "JPY": Decimal(string: "150.3")!,
        ],
        fetchedAt: .now
    )

    // MARK: - Identity

    @Test("Same currency returns exact identity")
    func sameCurrency() {
        let result = rates.convert(1234.56, from: "RUB", to: "RUB")
        #expect(result == 1234.56)
    }

    @Test("Same currency works for base currency too")
    func sameCurrencyBase() {
        #expect(rates.convert(100, from: "USD", to: "USD") == 100)
    }

    // MARK: - Cross-Rate Math

    @Test("USD to RUB uses rate directly")
    func usdToRub() {
        // USD→RUB: amount * 87.5 / 1 = 87.5
        let result = rates.convert(1, from: "USD", to: "RUB")
        #expect(result == Decimal(string: "87.5")!)
    }

    @Test("RUB to USD is inverse")
    func rubToUsd() {
        // RUB→USD: 87.5 * 1 / 87.5 = 1
        let result = rates.convert(Decimal(string: "87.5")!, from: "RUB", to: "USD")
        #expect(result == 1)
    }

    @Test("EUR to RUB cross-rate is correct")
    func eurToRub() {
        // EUR→RUB: amount * RUB_rate / EUR_rate = 10 * 87.5 / 0.92
        let result = rates.convert(10, from: "EUR", to: "RUB")
        let expected = Decimal(10) * Decimal(string: "87.5")! / Decimal(string: "0.92")!
        #expect(result == expected)
    }

    @Test("GBP to TRY cross-rate")
    func gbpToTry() {
        // GBP→TRY: amount * TRY_rate / GBP_rate = 100 * 38.2 / 0.79
        let result = rates.convert(100, from: "GBP", to: "TRY")
        let expected = Decimal(100) * Decimal(string: "38.2")! / Decimal(string: "0.79")!
        #expect(result == expected)
    }

    // MARK: - Base Currency Handling

    @Test("Base currency as source has implicit rate 1")
    func baseCurrencySource() {
        let result = rates.convert(50, from: "USD", to: "EUR")
        // 50 * 0.92 / 1 = 46
        #expect(result == Decimal(50) * Decimal(string: "0.92")!)
    }

    @Test("Base currency as target has implicit rate 1")
    func baseCurrencyTarget() {
        let result = rates.convert(92, from: "EUR", to: "USD")
        // 92 * 1 / 0.92 = 100
        #expect(result == Decimal(92) / Decimal(string: "0.92")!)
    }

    // MARK: - Unknown Currencies

    @Test("Unknown source currency returns nil")
    func unknownSource() {
        #expect(rates.convert(100, from: "XYZ", to: "RUB") == nil)
    }

    @Test("Unknown target currency returns nil")
    func unknownTarget() {
        #expect(rates.convert(100, from: "RUB", to: "XYZ") == nil)
    }

    @Test("Both currencies unknown returns nil")
    func bothUnknown() {
        #expect(rates.convert(100, from: "AAA", to: "BBB") == nil)
    }

    // MARK: - Zero & Negative

    @Test("Zero amount converts to zero, not nil")
    func zeroAmount() {
        let result = rates.convert(0, from: "USD", to: "RUB")
        #expect(result == 0)
    }

    @Test("Negative amount converts correctly without sign flip")
    func negativeAmount() {
        let result = rates.convert(-100, from: "USD", to: "RUB")
        #expect(result == Decimal(-100) * Decimal(string: "87.5")!)
    }

    // MARK: - Zero Rate Protection

    @Test("Zero source rate returns nil (division by zero protection)")
    func zeroSourceRate() {
        let broken = ExchangeRates(
            base: "USD",
            date: .now,
            rates: ["ZERO": 0, "RUB": 87.5],
            fetchedAt: .now
        )
        #expect(broken.convert(100, from: "ZERO", to: "RUB") == nil)
    }

    // MARK: - Precision & Scale

    @Test("Large amount doesn't overflow")
    func largeAmount() {
        let result = rates.convert(10_000_000, from: "USD", to: "JPY")
        #expect(result != nil)
        #expect(result! > 0)
        // 10M * 150.3 = 1.503B
        #expect(result == Decimal(10_000_000) * Decimal(string: "150.3")!)
    }

    @Test("Tiny rate preserves precision")
    func tinyRate() {
        let micro = ExchangeRates(
            base: "USD",
            date: .now,
            rates: ["MICRO": Decimal(string: "0.000001")!, "RUB": 87.5],
            fetchedAt: .now
        )
        let result = micro.convert(1, from: "MICRO", to: "RUB")
        #expect(result != nil)
        // 1 * 87.5 / 0.000001 = 87_500_000
        #expect(result == Decimal(string: "87.5")! / Decimal(string: "0.000001")!)
    }

    // MARK: - Empty Rates

    @Test("Empty rates returns nil for any conversion")
    func emptyRates() {
        #expect(ExchangeRates.empty.convert(100, from: "USD", to: "RUB") == nil)
        #expect(ExchangeRates.empty.convert(100, from: "EUR", to: "GBP") == nil)
    }

    @Test("Empty rates identity still works for base")
    func emptyRatesBase() {
        #expect(ExchangeRates.empty.convert(100, from: "USD", to: "USD") == 100)
    }

    // MARK: - Preview Rates Sanity

    @Test("Preview rates contain expected currencies")
    func previewRatesSanity() {
        let preview = ExchangeRates.preview
        #expect(preview.base == "USD")
        #expect(preview.rates["RUB"] != nil)
        #expect(preview.rates["EUR"] != nil)
        #expect(preview.rates["TRY"] != nil)

        // Spot-check: USD→RUB should be in a reasonable range
        let rubRate = preview.rates["RUB"]!
        #expect(rubRate > 50)
        #expect(rubRate < 200)
    }
}
