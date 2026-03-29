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
    /// Returns nil if either currency is unknown.
    func convert(_ amount: Decimal, from source: String, to target: String) -> Decimal? {
        guard source != target else { return amount }

        let sourceRate: Decimal? = source == base ? 1 : rates[source]
        let targetRate: Decimal? = target == base ? 1 : rates[target]

        guard let s = sourceRate, let t = targetRate, s != 0 else { return nil }
        return amount * t / s
    }

    static let empty = ExchangeRates(base: "USD", date: .distantPast, rates: [:], fetchedAt: .distantPast)
}

// MARK: - Exchange Rate Provider

/// Abstraction for fetching exchange rates.
/// Domain layer depends on this protocol; Data layer provides the implementation.
protocol ExchangeRateProvider: Sendable {
    /// Fetch the latest rates. Implementations handle caching internally.
    func latestRates() async throws -> ExchangeRates
}
