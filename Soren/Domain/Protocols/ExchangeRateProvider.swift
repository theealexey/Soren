import Foundation

// MARK: - Exchange Rates

/// Snapshot of exchange rates relative to a base currency.
/// Rates are fetched from an external API and cached locally.
struct ExchangeRates: Equatable, Sendable {
    /// Base currency code (e.g. "USD").
    let base: String
    /// Date when rates were published by the source.
    let date: Date
    /// Currency code → rate relative to base. Does not include base itself.
    let rates: [String: Decimal]
    /// When these rates were fetched (for staleness checks).
    let fetchedAt: Date

    /// Convert an amount between two currencies using cross-rate math.
    /// Compatibility adapter for screens not yet migrated to `ConvertMoneyUseCase`.
    func convert(_ amount: Decimal, from source: String, to target: String) -> Decimal? {
        guard let original = try? Money(amount: amount, currencyCode: source) else {
            return nil
        }
        let snapshot = ExchangeRateSnapshot(exchangeRates: self, freshness: .fresh)
        return try? ConvertMoneyUseCase()
            .execute(original: original, targetCurrencyCode: target, snapshot: snapshot)
            .converted.amount
    }

    static let empty = ExchangeRates(base: "USD", date: .distantPast, rates: [:], fetchedAt: .distantPast)
}

// MARK: - Exchange Rate Provider

/// Abstraction for fetching exchange rates.
/// Domain layer depends on this protocol; Data layer provides the implementation.
protocol ExchangeRateProvider: Sendable {
    /// Fetch rates together with their cache freshness.
    func latestSnapshot() async throws -> ExchangeRateSnapshot
}

extension ExchangeRateProvider {
    /// Compatibility adapter for existing callers during the staged migration.
    func latestRates() async throws -> ExchangeRates {
        try await latestSnapshot().exchangeRates
    }
}
