import Foundation
import Testing
@testable import Soren

@Suite("OpenExchangeRateProvider")
struct OpenExchangeRateProviderTests {
    private enum RequestFailure: Error {
        case offline
        case unexpectedRequest
    }

    private actor MemoryRateCache: ExchangeRateCache {
        private var stored: ExchangeRates?

        init(stored: ExchangeRates? = nil) {
            self.stored = stored
        }

        func load() async -> ExchangeRates? {
            stored
        }

        func save(_ rates: ExchangeRates) async {
            stored = rates
        }
    }

    private actor RequestStub {
        enum Outcome: Sendable {
            case response(ExchangeRateHTTPResponse)
            case failure
        }

        private var outcomes: [Outcome]
        private var calls = 0

        init(outcomes: [Outcome]) {
            self.outcomes = outcomes
        }

        func perform(url: URL) throws -> ExchangeRateHTTPResponse {
            calls += 1
            guard let outcome = outcomes.first else {
                throw RequestFailure.unexpectedRequest
            }
            outcomes.removeFirst()
            switch outcome {
            case .response(let response):
                return response
            case .failure:
                throw RequestFailure.offline
            }
        }

        func callCount() -> Int {
            calls
        }
    }

    private func rates(fetchedAt: Date) -> ExchangeRates {
        ExchangeRates(
            base: "USD",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            rates: ["RUB": 90],
            fetchedAt: fetchedAt
        )
    }

    private func successResponse() throws -> ExchangeRateHTTPResponse {
        let json = """
        {
          "result": "success",
          "base_code": "USD",
          "time_last_update_utc": "Mon, 14 Jul 2026 00:00:00 +0000",
          "rates": { "RUB": 90.0, "EUR": 0.9 }
        }
        """
        let data = try #require(json.data(using: .utf8))
        return ExchangeRateHTTPResponse(data: data, statusCode: 200)
    }

    @Test("Fresh disk cache returns a fresh snapshot without network")
    func freshDiskCache() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cached = rates(fetchedAt: now.addingTimeInterval(-3_600))
        let cache = MemoryRateCache(stored: cached)
        let request = RequestStub(outcomes: [])
        let provider = OpenExchangeRateProvider(
            cache: cache,
            now: { now },
            request: { url in try await request.perform(url: url) }
        )

        let snapshot = try await provider.latestSnapshot()

        #expect(snapshot.exchangeRates == cached)
        #expect(snapshot.freshness == .fresh)
        #expect(await request.callCount() == 0)
    }

    @Test("Successful network result is fresh and reused from memory")
    func networkThenMemory() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cache = MemoryRateCache()
        let request = RequestStub(outcomes: [.response(try successResponse())])
        let provider = OpenExchangeRateProvider(
            cache: cache,
            now: { now },
            request: { url in try await request.perform(url: url) }
        )

        let first = try await provider.latestSnapshot()
        let second = try await provider.latestSnapshot()

        #expect(first.freshness == .fresh)
        #expect(first.fetchedAt == now)
        #expect(second == first)
        #expect(await request.callCount() == 1)
        #expect(await cache.load() == first.exchangeRates)
    }

    @Test("Network failure returns stale last-known snapshot with age")
    func staleFallback() async throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let age: TimeInterval = 7 * 3_600
        let cached = rates(fetchedAt: now.addingTimeInterval(-age))
        let cache = MemoryRateCache(stored: cached)
        let request = RequestStub(outcomes: [.failure])
        let provider = OpenExchangeRateProvider(
            cache: cache,
            now: { now },
            request: { url in try await request.perform(url: url) }
        )

        let snapshot = try await provider.latestSnapshot()

        #expect(snapshot.exchangeRates == cached)
        #expect(snapshot.freshness == .stale(age: age))
        #expect(snapshot.fetchedAt == cached.fetchedAt)
        #expect(await cache.load() == cached)
    }

    @Test("Network failure without cache returns typed unavailable error")
    func unavailableWithoutCache() async {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let cache = MemoryRateCache()
        let request = RequestStub(outcomes: [.failure])
        let provider = OpenExchangeRateProvider(
            cache: cache,
            now: { now },
            request: { url in try await request.perform(url: url) }
        )

        await #expect(throws: ExchangeRateError.unavailable) {
            try await provider.latestSnapshot()
        }
    }
}
