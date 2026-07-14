import Foundation

// MARK: - Exchange Rate Snapshot

enum ExchangeRateFreshness: Equatable, Sendable {
    case fresh
    case stale(age: TimeInterval)
}

/// Rates together with the cache freshness visible to production callers.
struct ExchangeRateSnapshot: Equatable, Sendable {
    let exchangeRates: ExchangeRates
    let freshness: ExchangeRateFreshness

    var baseCurrencyCode: String { exchangeRates.base }
    var rates: [String: Decimal] { exchangeRates.rates }
    var providerDate: Date { exchangeRates.date }
    var fetchedAt: Date { exchangeRates.fetchedAt }
}
