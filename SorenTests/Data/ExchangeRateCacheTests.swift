import Testing
import Foundation
@testable import Soren

// MARK: - Exchange Rate Cache Tests (Adversarial)

/// Tests UserDefaults-backed rate cache for round-trip fidelity,
/// overwrite correctness, and precision preservation.

@Suite("ExchangeRateCache")
struct ExchangeRateCacheTests {

    /// Isolated UserDefaults suite — no leakage to real defaults.
    private func makeCache() -> UserDefaultsExchangeRateCache {
        let suite = UserDefaults(suiteName: "test.exchangeRateCache.\(UUID().uuidString)")!
        return UserDefaultsExchangeRateCache(defaults: suite)
    }

    private func makeSampleRates(
        rates: [String: Decimal] = ["RUB": 87.5, "EUR": 0.92],
        fetchedAt: Date = .now
    ) -> ExchangeRates {
        ExchangeRates(base: "USD", date: fetchedAt, rates: rates, fetchedAt: fetchedAt)
    }

    // MARK: - Round-Trip

    @Test("Save then load returns equal rates")
    func roundTrip() {
        let cache = makeCache()
        let original = makeSampleRates()

        cache.save(original)
        let loaded = cache.load()

        #expect(loaded != nil)
        #expect(loaded?.base == original.base)
        #expect(loaded?.rates == original.rates)
    }

    // MARK: - Empty State

    @Test("Load from empty defaults returns nil")
    func emptyDefaults() {
        let cache = makeCache()
        #expect(cache.load() == nil)
    }

    // MARK: - Overwrite

    @Test("Second save overwrites first — load returns latest")
    func overwrite() {
        let cache = makeCache()

        let first = makeSampleRates(rates: ["RUB": 80])
        let second = makeSampleRates(rates: ["RUB": 95])

        cache.save(first)
        cache.save(second)

        let loaded = cache.load()
        #expect(loaded?.rates["RUB"] == 95)
    }

    // MARK: - Decimal Precision

    @Test("Decimal precision survives round-trip")
    func decimalPrecision() {
        let cache = makeCache()
        let precise = makeSampleRates(rates: [
            "PRECISE": Decimal(string: "87.123456")!,
            "TINY": Decimal(string: "0.000001")!,
        ])

        cache.save(precise)
        let loaded = cache.load()

        #expect(loaded?.rates["PRECISE"] == Decimal(string: "87.123456")!)
        #expect(loaded?.rates["TINY"] == Decimal(string: "0.000001")!)
    }

    // MARK: - Large Dictionary

    @Test("50-currency dictionary survives without data loss")
    func largeDictionary() {
        let cache = makeCache()

        var bigRates: [String: Decimal] = [:]
        for i in 0..<50 {
            bigRates["CUR\(String(format: "%02d", i))"] = Decimal(i + 1) + Decimal(string: "0.5")!
        }

        let rates = makeSampleRates(rates: bigRates)
        cache.save(rates)
        let loaded = cache.load()

        #expect(loaded != nil)
        #expect(loaded?.rates.count == 50)
        #expect(loaded?.rates["CUR00"] == Decimal(string: "1.5")!)
        #expect(loaded?.rates["CUR49"] == Decimal(string: "50.5")!)
    }

    // MARK: - Isolation

    @Test("Different cache instances don't leak data")
    func isolation() {
        let cache1 = makeCache()
        let cache2 = makeCache()

        cache1.save(makeSampleRates(rates: ["RUB": 87.5]))

        #expect(cache2.load() == nil, "Cache2 should not see Cache1's data")
    }
}
