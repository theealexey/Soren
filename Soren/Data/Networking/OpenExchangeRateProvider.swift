import Foundation

// MARK: - Open Exchange Rate Provider

/// Fetches live rates from open.er-api.com (free, no API key, 168 currencies).
/// Uses a 3-tier caching strategy: in-memory → disk → network → stale fallback.
actor OpenExchangeRateProvider: ExchangeRateProvider {

    private let staleness: TimeInterval
    private let now: @Sendable () -> Date
    private let loadCachedRates: @Sendable () async -> ExchangeRates?
    private let saveCachedRates: @Sendable (ExchangeRates) async -> Void
    private let request: @Sendable (URL) async throws -> ExchangeRateHTTPResponse

    private var inMemoryRates: ExchangeRates?

    private static let apiURLString = "https://open.er-api.com/v6/latest/USD"

    init(
        session: URLSession = .shared,
        staleness: TimeInterval = 6 * 3600
    ) {
        let cache = UserDefaultsExchangeRateCache()
        self.staleness = staleness
        self.now = Date.init
        self.loadCachedRates = { await cache.load() }
        self.saveCachedRates = { rates in await cache.save(rates) }
        self.request = { url in
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                throw ExchangeRateError.serverError
            }
            return ExchangeRateHTTPResponse(data: data, statusCode: http.statusCode)
        }
    }

    init<Cache: ExchangeRateCache>(
        cache: Cache,
        staleness: TimeInterval = 6 * 3600,
        now: @escaping @Sendable () -> Date,
        request: @escaping @Sendable (URL) async throws -> ExchangeRateHTTPResponse
    ) {
        self.staleness = staleness
        self.now = now
        self.loadCachedRates = { await cache.load() }
        self.saveCachedRates = { rates in await cache.save(rates) }
        self.request = request
    }

    func latestSnapshot() async throws -> ExchangeRateSnapshot {
        let currentDate = now()

        // 1. In-memory cache (fresh)
        if let cached = inMemoryRates, isFresh(cached, at: currentDate) {
            return snapshot(for: cached, at: currentDate)
        }

        // 2. Disk cache (fresh)
        let diskCached = await loadCachedRates()
        if let diskCached, isFresh(diskCached, at: currentDate) {
            inMemoryRates = diskCached
            return snapshot(for: diskCached, at: currentDate)
        }

        // 3. Network fetch
        do {
            let rates = try await fetchFromAPI()
            await saveCachedRates(rates)
            inMemoryRates = rates
            return snapshot(for: rates, at: now())
        } catch {
            // 4. Stale fallback
            if let stale = inMemoryRates ?? diskCached {
                return snapshot(for: stale, at: now())
            }
            throw ExchangeRateError.unavailable
        }
    }

    // MARK: - Private

    private func isFresh(_ rates: ExchangeRates, at currentDate: Date) -> Bool {
        currentDate.timeIntervalSince(rates.fetchedAt) < staleness
    }

    private func snapshot(for rates: ExchangeRates, at currentDate: Date) -> ExchangeRateSnapshot {
        let age = max(0, currentDate.timeIntervalSince(rates.fetchedAt))
        let freshness: ExchangeRateFreshness = age < staleness ? .fresh : .stale(age: age)
        return ExchangeRateSnapshot(exchangeRates: rates, freshness: freshness)
    }

    private func fetchFromAPI() async throws -> ExchangeRates {
        guard let apiURL = URL(string: Self.apiURLString) else {
            throw ExchangeRateError.invalidEndpoint
        }
        let response = try await request(apiURL)
        guard response.statusCode == 200 else {
            throw ExchangeRateError.serverError
        }

        let decoded = try JSONDecoder().decode(OpenERResponse.self, from: response.data)
        guard decoded.result == "success" else {
            throw ExchangeRateError.serverError
        }

        let fetchedAt = now()

        return ExchangeRates(
            base: decoded.baseCode,
            date: decoded.parsedDate ?? fetchedAt,
            rates: decoded.rates,
            fetchedAt: fetchedAt
        )
    }
}

struct ExchangeRateHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
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
enum ExchangeRateError: Error, Equatable, Sendable {
    case invalidEndpoint
    case serverError
    case unavailable
}

// MARK: - Static Provider for Previews

/// Returns hardcoded rates for SwiftUI previews and tests.
struct StaticExchangeRateProvider: ExchangeRateProvider {
    var rates: ExchangeRates
    var freshness: ExchangeRateFreshness

    init(rates: ExchangeRates = .preview, freshness: ExchangeRateFreshness = .fresh) {
        self.rates = rates
        self.freshness = freshness
    }

    func latestSnapshot() async throws -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(exchangeRates: rates, freshness: freshness)
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
