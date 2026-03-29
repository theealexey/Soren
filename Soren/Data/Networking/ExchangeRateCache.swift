import Foundation

// MARK: - Exchange Rate Cache Protocol

/// Abstraction for persisting exchange rates between app launches.
protocol ExchangeRateCache: Sendable {
    func load() -> ExchangeRates?
    func save(_ rates: ExchangeRates)
}

// MARK: - UserDefaults Implementation

/// Persists exchange rates in UserDefaults as JSON.
final class UserDefaultsExchangeRateCache: ExchangeRateCache, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "soren.exchangeRates"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> ExchangeRates? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CodableExchangeRates.self, from: data).toDomain()
    }

    func save(_ rates: ExchangeRates) {
        let codable = CodableExchangeRates(from: rates)
        if let data = try? JSONEncoder().encode(codable) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Codable Wrapper

/// Private Codable wrapper for ExchangeRates (Domain type stays Codable-free).
private struct CodableExchangeRates: Codable {
    let base: String
    let date: Date
    let rates: [String: Decimal]
    let fetchedAt: Date

    init(from domain: ExchangeRates) {
        self.base = domain.base
        self.date = domain.date
        self.rates = domain.rates
        self.fetchedAt = domain.fetchedAt
    }

    func toDomain() -> ExchangeRates {
        ExchangeRates(base: base, date: date, rates: rates, fetchedAt: fetchedAt)
    }
}
