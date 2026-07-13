import Testing
import Foundation
import UIKit
@testable import Soren

// MARK: - Provider Logo Resolution Tests

@Suite("Provider logos — Resolution")
struct ProviderLogoResolutionTests {

    @Test("Remote logo fallback does not use retired Clearbit host")
    func remoteLogoFallbackUsesVerifiedHost() throws {
        let provider = try #require(ProviderCatalog.template(forProviderID: "spotify"))
        let urls = ProviderLogoResolver.logoURLs(for: provider)

        #expect(urls.count == 1)
        #expect(urls.first?.host() == "t1.gstatic.com")
        #expect(urls.allSatisfy { $0.host() != "logo.clearbit.com" })
    }

    @Test("Custom provider without a logo source uses a placeholder")
    @MainActor
    func customProviderWithoutLogoSourceUsesPlaceholder() {
        let provider = ProviderTemplate(
            id: "custom_test_provider",
            displayName: "Custom",
            category: .other,
            brandColorHex: "#123456"
        )

        #expect(ProviderIcon.resolution(for: provider) == .letterMark)
    }

    @Test(
        "Screenshot-critical providers resolve to bundled assets",
        arguments: [
            "spotify", "yandex_plus", "mts_premium", "mts", "chatgpt_plus",
            "icloud", "netflix", "nordvpn", "x_premium", "youtube_premium",
            "telegram_premium", "qobuz", "github_copilot",
        ]
    )
    @MainActor
    func screenshotProviderUsesBundledAsset(providerID: String) throws {
        let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
        #expect(ProviderIcon.resolution(for: provider) == .asset("provider_\(providerID)"))
    }
}

// MARK: - Provider Catalog Tests (Aggressive)

@Suite("ProviderCatalog — Integrity")
struct ProviderCatalogIntegrityTests {

    @Test("No duplicate IDs across entire catalog")
    func noDuplicateIDs() {
        let all = ProviderCatalog.all
        let ids = all.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count,
                "Duplicate IDs found: \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
    }

    @Test("Every provider has a non-empty displayName")
    func nonEmptyDisplayNames() {
        for provider in ProviderCatalog.all {
            #expect(!provider.displayName.isEmpty, "Provider \(provider.id) has empty displayName")
        }
    }

    @Test("Every provider has a valid currency code (3 uppercase letters)")
    func validCurrencyCodes() {
        let validPattern = /^[A-Z]{3}$/
        for provider in ProviderCatalog.all {
            #expect(provider.suggestedCurrencyCode.wholeMatch(of: validPattern) != nil,
                    "Provider \(provider.id) has invalid currency code: \(provider.suggestedCurrencyCode)")
        }
    }

    @Test("Every Russian provider uses RUB")
    func russianProvidersUseRUB() {
        let ruProviders = ProviderCatalog.russia
        for provider in ruProviders {
            #expect(provider.suggestedCurrencyCode == "RUB",
                    "RU provider \(provider.id) uses \(provider.suggestedCurrencyCode) instead of RUB")
        }
    }

    @Test("Every Russian provider has region = .russia")
    func russianProvidersHaveCorrectRegion() {
        for provider in ProviderCatalog.russia {
            #expect(provider.region == .russia,
                    "Provider \(provider.id) is in RU pack but has region \(provider.region)")
        }
    }

    @Test("Every global provider has region = .global")
    func globalProvidersHaveCorrectRegion() {
        for provider in ProviderCatalog.global {
            #expect(provider.region == .global,
                    "Provider \(provider.id) is in global pack but has region \(provider.region)")
        }
    }

    @Test("Catalog has at least 40 providers")
    func minimumProviderCount() {
        #expect(ProviderCatalog.all.count >= 40,
                "Catalog is suspiciously small: \(ProviderCatalog.all.count)")
    }

    @Test("Russia pack has at least 20 providers")
    func minimumRussianCount() {
        #expect(ProviderCatalog.russia.count >= 20,
                "RU pack is too small: \(ProviderCatalog.russia.count)")
    }

    @Test("ID format: lowercase, no spaces, only a-z 0-9 and underscores")
    func idFormatIsClean() {
        let validPattern = /^[a-z0-9_]+$/
        for provider in ProviderCatalog.all {
            #expect(provider.id.wholeMatch(of: validPattern) != nil,
                    "Provider ID '\(provider.id)' contains invalid characters")
        }
    }

    @Test("No provider has empty tags array")
    func nonEmptyTags() {
        for provider in ProviderCatalog.all {
            #expect(!provider.tags.isEmpty,
                    "Provider \(provider.id) has no tags — this will break tag-based filtering")
        }
    }

    @Test("Key RU ecosystem bundles exist: Яндекс Плюс, СберПрайм+, МТС Premium, Т-Банк Pro")
    func keyRussianEcosystemsPresent() {
        let required = ["yandex_plus", "sber_prime", "mts_premium", "tbank_pro"]
        let existing = Set(ProviderCatalog.russia.map(\.id))
        for id in required {
            #expect(existing.contains(id), "Missing critical RU ecosystem: \(id)")
        }
    }

    @Test("Key RU mobile operators exist: МТС, МегаФон, Билайн, Т2, Yota")
    func keyRussianTelecomsPresent() {
        let required = ["mts", "megafon", "beeline", "t2", "yota"]
        let existing = Set(ProviderCatalog.russia.map(\.id))
        for id in required {
            #expect(existing.contains(id), "Missing RU telecom: \(id)")
        }
    }

    @Test("Key RU video services exist: Кинопоиск, KION, Okko, Start, Wink, IVI")
    func keyRussianVideoPresent() {
        let required = ["kinopoisk", "kion", "okko", "start", "wink", "ivi"]
        let existing = Set(ProviderCatalog.russia.map(\.id))
        for id in required {
            #expect(existing.contains(id), "Missing RU video service: \(id)")
        }
    }

    @Test("Key global services exist: Netflix, Spotify, YouTube Premium, iCloud+, ChatGPT")
    func keyGlobalServicesPresent() {
        let required = ["netflix", "spotify", "youtube_premium", "icloud", "chatgpt_plus"]
        let existing = Set(ProviderCatalog.global.map(\.id))
        for id in required {
            #expect(existing.contains(id), "Missing global service: \(id)")
        }
    }

    @Test("Ecosystem bundles have itemType = .ecosystemBundle")
    func ecosystemBundlesCorrectType() {
        let expectedBundles = ["yandex_plus", "sber_prime", "mts_premium", "apple_one"]
        for id in expectedBundles {
            let provider = ProviderCatalog.all.first { $0.id == id }
            #expect(provider?.itemType == .ecosystemBundle,
                    "\(id) should be .ecosystemBundle, got \(String(describing: provider?.itemType))")
        }
    }

    @Test("Mobile plans have itemType = .mobilePlan")
    func mobilePlansCorrectType() {
        let expected = ["mts", "megafon", "beeline", "t2", "yota"]
        for id in expected {
            let provider = ProviderCatalog.all.first { $0.id == id }
            #expect(provider?.itemType == .mobilePlan,
                    "\(id) should be .mobilePlan, got \(String(describing: provider?.itemType))")
        }
    }
}

// MARK: - Logo Loader Tests

@Suite("LogoLoader — Reliability")
struct LogoLoaderReliabilityTests {

    @Test("Concurrent callers share one request and one caller cannot cancel it")
    func concurrentRequestsAreCoalesced() async throws {
        let url = try #require(URL(string: "https://example.test/logo.png"))
        let imageData = try validPNGData()
        let stub = LogoDataStub(
            responses: [.init(statusCode: 200, mimeType: "image/png", data: imageData)],
            delay: .milliseconds(100)
        )
        let loader = makeLoader(stub: stub)

        let first = Task { await loader.image(for: [url]) }
        try await Task.sleep(for: .milliseconds(20))
        let second = Task { await loader.image(for: [url]) }
        first.cancel()

        let secondImage = await second.value
        _ = await first.value
        let cachedImage = await loader.image(for: [url])

        #expect(secondImage != nil)
        #expect(cachedImage != nil)
        #expect(await stub.requestCount == 1)
    }

    @Test("Failed request is not cached and a later request retries")
    func failureCanRetry() async throws {
        let url = try #require(URL(string: "https://example.test/retry.png"))
        let imageData = try validPNGData()
        let stub = LogoDataStub(responses: [
            .init(statusCode: 500, mimeType: "image/png", data: imageData),
            .init(statusCode: 200, mimeType: "image/png", data: imageData),
        ])
        let loader = makeLoader(stub: stub)

        let failed = await loader.image(for: [url])
        let retried = await loader.image(for: [url])

        #expect(failed == nil)
        #expect(retried != nil)
        #expect(await stub.requestCount == 2)
    }

    @Test("Invalid HTTP, MIME and image data fail safely")
    func invalidResponsesFailSafely() async throws {
        let url = try #require(URL(string: "https://example.test/invalid.png"))
        let imageData = try validPNGData()
        let invalidResponses = [
            LogoDataStub.Response(statusCode: 404, mimeType: "image/png", data: imageData),
            LogoDataStub.Response(statusCode: 200, mimeType: "text/html", data: imageData),
            LogoDataStub.Response(statusCode: 200, mimeType: "image/png", data: Data("invalid".utf8)),
        ]

        for response in invalidResponses {
            let stub = LogoDataStub(responses: [response])
            let loader = makeLoader(stub: stub)
            #expect(await loader.image(for: [url]) == nil)
        }
    }

    private func makeLoader(stub: LogoDataStub) -> LogoLoader {
        LogoLoader { url in
            try await stub.load(url)
        }
    }

    private func validPNGData() throws -> Data {
        try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))
    }
}

private actor LogoDataStub {
    struct Response: Sendable {
        let statusCode: Int
        let mimeType: String
        let data: Data
    }

    enum StubError: Error {
        case noResponse
        case invalidHTTPResponse
    }

    private var responses: [Response]
    private let delay: Duration
    private(set) var requestCount = 0

    init(responses: [Response], delay: Duration = .zero) {
        self.responses = responses
        self.delay = delay
    }

    func load(_ url: URL) async throws -> (Data, URLResponse) {
        requestCount += 1
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        guard !responses.isEmpty else {
            throw StubError.noResponse
        }

        let response = responses.removeFirst()
        guard let http = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": response.mimeType]
        ) else {
            throw StubError.invalidHTTPResponse
        }
        return (response.data, http)
    }
}

// MARK: - Search Tests

@Suite("ProviderCatalog — Search")
struct ProviderCatalogSearchTests {

    let repo = InMemoryProviderCatalogRepository()

    @Test("Search 'нетфликс' finds Netflix (Cyrillic alias)")
    func searchCyrillicAlias() async {
        let results = await repo.search(query: "нетфликс")
        #expect(results.contains { $0.id == "netflix" })
    }

    @Test("Search 'яндекс' finds multiple Yandex services")
    func searchYandexFindsMultiple() async {
        let results = await repo.search(query: "яндекс")
        #expect(results.count >= 3, "Expected at least 3 Yandex services, got \(results.count)")
    }

    @Test("Search is case-insensitive")
    func searchCaseInsensitive() async {
        let upper = await repo.search(query: "NETFLIX")
        let lower = await repo.search(query: "netflix")
        #expect(upper.count == lower.count)
    }

    @Test("Empty search returns all providers")
    func emptySearchReturnsAll() async {
        let results = await repo.search(query: "")
        #expect(results.count == ProviderCatalog.all.count)
    }

    @Test("Search with spaces only returns all")
    func spacesOnlyReturnsAll() async {
        let results = await repo.search(query: "   ")
        #expect(results.count == ProviderCatalog.all.count)
    }

    @Test("Search 'xyzgibberish' returns empty")
    func nonsenseSearchReturnsEmpty() async {
        let results = await repo.search(query: "xyzgibberish123")
        #expect(results.isEmpty)
    }

    @Test("Fetch by ID returns exact provider")
    func fetchByID() async {
        let result = await repo.fetch(id: "yandex_plus")
        #expect(result?.displayName == "Яндекс Плюс")
    }

    @Test("Fetch by unknown ID returns nil")
    func fetchUnknownID() async {
        let result = await repo.fetch(id: "nonexistent_service_xyz")
        #expect(result == nil)
    }

    @Test("FetchByRegion .russia returns only RU providers")
    func fetchByRegionRussia() async {
        let results = await repo.fetchByRegion(.russia)
        #expect(results.allSatisfy { $0.region == .russia })
        #expect(!results.isEmpty)
    }

    @Test("FetchByCategory .video returns only video providers")
    func fetchByCategoryVideo() async {
        let results = await repo.fetchByCategory(.video)
        #expect(results.allSatisfy { $0.category == .video })
        #expect(results.count >= 5)  // Netflix, YouTube, Disney+, HBO, Apple TV+, RU services
    }

    // MARK: - Social & Creator Platform Search

    @Test("Search 'Instagram' finds Meta Verified (alias)")
    func searchInstagramFindsMetaVerified() async {
        let results = await repo.search(query: "instagram")
        #expect(results.contains { $0.id == "meta_verified" },
                "Expected 'meta_verified' in results for query 'instagram'")
    }

    @Test("Search 'Facebook' finds Meta Verified (alias)")
    func searchFacebookFindsMetaVerified() async {
        let results = await repo.search(query: "facebook")
        #expect(results.contains { $0.id == "meta_verified" })
    }

    @Test("Search 'Twitter' finds X Premium (alias)")
    func searchTwitterFindsXPremium() async {
        let results = await repo.search(query: "twitter")
        #expect(results.contains { $0.id == "x_premium" },
                "Expected 'x_premium' in results for query 'twitter'")
    }

    @Test("Search 'Twitter Blue' finds X Premium (alias)")
    func searchTwitterBlueFindsXPremium() async {
        let results = await repo.search(query: "twitter blue")
        #expect(results.contains { $0.id == "x_premium" })
    }

    @Test("Search 'X Premium' finds X Premium (displayName)")
    func searchXPremiumDisplayName() async {
        let results = await repo.search(query: "x premium")
        #expect(results.contains { $0.id == "x_premium" })
    }

    @Test("Search 'Telegram' finds Telegram Premium (alias)")
    func searchTelegramFindsPremium() async {
        let results = await repo.search(query: "telegram")
        #expect(results.contains { $0.id == "telegram_premium" })
    }

    @Test("Search 'Discord' finds Discord Nitro (alias)")
    func searchDiscordFindsNitro() async {
        let results = await repo.search(query: "discord")
        #expect(results.contains { $0.id == "discord_nitro" })
    }

    @Test("Search 'Reddit' finds Reddit Premium (alias)")
    func searchRedditFindsPremium() async {
        let results = await repo.search(query: "reddit")
        #expect(results.contains { $0.id == "reddit_premium" })
    }

    // MARK: - Dating App Search

    @Test("Search 'Grindr' finds Grindr (displayName)")
    func searchGrindrFindsGrindr() async {
        let results = await repo.search(query: "grindr")
        #expect(results.contains { $0.id == "grindr" })
    }

    @Test("Search 'Grindr XTRA' finds Grindr (alias)")
    func searchGrindrXTRAFindsGrindr() async {
        let results = await repo.search(query: "grindr xtra")
        #expect(results.contains { $0.id == "grindr" })
    }

    @Test("Search 'XTRA' finds Grindr via partial alias match")
    func searchXTRAFindsGrindr() async {
        let results = await repo.search(query: "xtra")
        #expect(results.contains { $0.id == "grindr" })
    }

    @Test("Search 'Hornet' finds Hornet (displayName)")
    func searchHornetFindsHornet() async {
        let results = await repo.search(query: "hornet")
        #expect(results.contains { $0.id == "hornet" })
    }

    @Test("Search 'Hornet Premium' finds Hornet (alias)")
    func searchHornetPremiumFindsHornet() async {
        let results = await repo.search(query: "hornet premium")
        #expect(results.contains { $0.id == "hornet" })
    }
}
