import Foundation

// MARK: - Open Exchange Rate Provider

/// Fetches live rates from open.er-api.com (free, no API key, 168 currencies).
/// Uses a 3-tier caching strategy: in-memory → disk → network → stale fallback.
actor OpenExchangeRateProvider: ExchangeRateProvider {

    private let session: URLSession
    private let cache: ExchangeRateCache
    private let staleness: TimeInterval

    private var inMemoryRates: ExchangeRates?

    private static let apiURL = URL(string: "https://open.er-api.com/v6/latest/USD")!

    init(
        session: URLSession = .shared,
        cache: ExchangeRateCache = UserDefaultsExchangeRateCache(),
        staleness: TimeInterval = 6 * 3600
    ) {
        self.session = session
        self.cache = cache
        self.staleness = staleness
    }

    func latestRates() async throws -> ExchangeRates {
        // 1. In-memory cache (fresh)
        if let cached = inMemoryRates, isFresh(cached) {
            return cached
        }

        // 2. Disk cache (fresh)
        if let diskCached = cache.load(), isFresh(diskCached) {
            inMemoryRates = diskCached
            return diskCached
        }

        // 3. Network fetch
        do {
            let rates = try await fetchFromAPI()
            cache.save(rates)
            inMemoryRates = rates
            return rates
        } catch {
            // 4. Stale fallback
            if let stale = inMemoryRates ?? cache.load() {
                return stale
            }
            throw ExchangeRateError.noRatesAvailable
        }
    }

    // MARK: - Private

    private func isFresh(_ rates: ExchangeRates) -> Bool {
        Date().timeIntervalSince(rates.fetchedAt) < staleness
    }

    private func fetchFromAPI() async throws -> ExchangeRates {
        let (data, response) = try await session.data(from: Self.apiURL)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ExchangeRateError.serverError
        }

        let decoded = try JSONDecoder().decode(OpenERResponse.self, from: data)
        guard decoded.result == "success" else {
            throw ExchangeRateError.serverError
        }

        return ExchangeRates(
            base: decoded.baseCode,
            date: decoded.parsedDate ?? .now,
            rates: decoded.rates,
            fetchedAt: .now
        )
    }
}

// MARK: - API Response

private struct OpenERResponse: Decodable {
    let result: String
    let baseCode: String
    let timeLastUpdateUtc: String
    let rates: [String: Decimal]

    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: timeLastUpdateUtc)
    }

    enum CodingKeys: String, CodingKey {
        case result
        case baseCode = "base_code"
        case timeLastUpdateUtc = "time_last_update_utc"
        case rates
    }
}

// MARK: - Errors

/// Typed failures from the exchange-rate networking layer.
/// Localized user-facing messages, if ever needed, must be produced
/// by a formatter in the presentation layer — not here.
enum ExchangeRateError: Error {
    case serverError
    case noRatesAvailable
}

// MARK: - Static Provider for Previews

/// Returns hardcoded rates for SwiftUI previews and tests.
struct StaticExchangeRateProvider: ExchangeRateProvider {
    var rates: ExchangeRates

    init(rates: ExchangeRates = .preview) {
        self.rates = rates
    }

    func latestRates() async throws -> ExchangeRates {
        rates
    }
}

extension ExchangeRates {
    static let preview = ExchangeRates(
        base: "USD",
        date: .now,
        rates: [
            "RUB": 87.5, "EUR": 0.92, "GBP": 0.79, "TRY": 38.2,
            "KZT": 483, "BYN": 2.97, "GEL": 2.7, "AMD": 377,
            "AED": 3.67, "JPY": 150.3, "CNY": 7.24,
        ],
        fetchedAt: .now
    )
}
