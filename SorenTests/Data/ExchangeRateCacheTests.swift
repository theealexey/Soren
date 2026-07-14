import Foundation
import Testing
@testable import Soren

@Suite("ExchangeRateCache")
struct ExchangeRateCacheTests {
    private func makeCache() throws -> UserDefaultsExchangeRateCache {
        let suiteName = "test.exchangeRateCache.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        return UserDefaultsExchangeRateCache(defaults: defaults)
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value))
    }

    private func makeSampleRates(
        rates: [String: Decimal],
        providerDate: Date,
        fetchedAt: Date
    ) -> ExchangeRates {
        ExchangeRates(base: "USD", date: providerDate, rates: rates, fetchedAt: fetchedAt)
    }

    @Test("Cache round-trip preserves Decimal rates and timestamps")
    func roundTripPreservesValue() async throws {
        let cache = try makeCache()
        let providerDate = Date(timeIntervalSince1970: 1_700_000_000)
        let fetchedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let original = makeSampleRates(
            rates: [
                "RUB": try decimal("87.123456"),
                "TINY": try decimal("0.000001"),
            ],
            providerDate: providerDate,
            fetchedAt: fetchedAt
        )

        await cache.save(original)
        let loaded = await cache.load()

        #expect(loaded == original)
    }

    @Test("Empty cache returns nil")
    func emptyDefaults() async throws {
        let cache = try makeCache()
        #expect(await cache.load() == nil)
    }

    @Test("Second save replaces the previous snapshot")
    func overwrite() async throws {
        let cache = try makeCache()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let first = makeSampleRates(rates: ["RUB": 80], providerDate: date, fetchedAt: date)
        let second = makeSampleRates(rates: ["RUB": 95], providerDate: date, fetchedAt: date)

        await cache.save(first)
        await cache.save(second)

        #expect(await cache.load() == second)
    }

    @Test("Independent cache suites do not share values")
    func isolation() async throws {
        let firstCache = try makeCache()
        let secondCache = try makeCache()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let rates = makeSampleRates(rates: ["RUB": 87.5], providerDate: date, fetchedAt: date)

        await firstCache.save(rates)

        #expect(await secondCache.load() == nil)
    }
}
