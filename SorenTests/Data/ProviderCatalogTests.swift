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

    @Test("Service-level source precedes an explicitly allowed company fallback")
    func serviceLogoSourcePrecedesCompanyFallback() {
        let provider = ProviderTemplate(
            id: "service_with_company_fallback",
            displayName: "Service",
            category: .other,
            serviceLogoSourceURL: URL(string: "https://service.example.com/logo.png"),
            companyLogoFallbackDomain: "example.com"
        )
        let sources = originalSources(for: provider)
        #expect(sources == ["https://service.example.com/logo.png", "https://example.com"])
    }

    @Test("Website metadata does not implicitly enable a company favicon")
    func companyFallbackRequiresExplicitMetadata() {
        let provider = ProviderTemplate(
            id: "service_only",
            displayName: "Service",
            category: .other,
            managementURL: URL(string: "https://example.com/account")
        )

        #expect(originalSources(for: provider).isEmpty)
        #expect(provider.companyLogoFallbackDomain == nil)
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
            "spotify", "yandex_plus", "mts_premium", "mts", "chatgpt_plus", "apple_music",
            "icloud", "netflix", "nordvpn", "x_premium", "youtube_premium",
            "telegram_premium", "qobuz", "github_copilot",
        ]
    )
    @MainActor
    func screenshotProviderUsesBundledAsset(providerID: String) throws {
        let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
        #expect(ProviderIcon.resolution(for: provider) == .asset("provider_\(providerID)"))
    }

    @Test(
        "Targeted curated services resolve to bundled service identities",
        arguments: ["yandex_plus", "kindle_unlimited", "onedrive", "notion_ai"]
    )
    @MainActor
    func targetedCuratedServiceUsesBundledAsset(providerID: String) throws {
        let provider = try #require(ProviderCatalog.template(forProviderID: providerID))

        if providerID != "yandex_plus" {
            #expect(provider.companyLogoFallbackDomain == nil)
        }
        #expect(ProviderIcon.resolution(for: provider) == .asset("provider_\(providerID)"))
    }

    @Test("Audited large-tile raster assets meet the source-resolution floor")
    func auditedLargeTileRasterAssetsMeetSourceResolutionFloor() throws {
        let assetNames = ["provider_yandex_plus", "provider_notion_ai"]
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let providersDirectory = repositoryRoot
            .appendingPathComponent("Soren/Resources/Assets.xcassets/Providers", isDirectory: true)

        for assetName in assetNames {
            let assetURL = providersDirectory
                .appendingPathComponent("\(assetName).imageset", isDirectory: true)
                .appendingPathComponent("logo.png")
            let image = try #require(UIImage(contentsOfFile: assetURL.path))
            let cgImage = try #require(image.cgImage)
            let dimensions = "\(cgImage.width)×\(cgImage.height)"

            #expect(
                cgImage.width == cgImage.height,
                "\(assetName) must be square; actual dimensions: \(dimensions)"
            )
            #expect(
                cgImage.width >= 256 && cgImage.height >= 256,
                "\(assetName) must be at least 256×256; actual dimensions: \(dimensions)"
            )
        }
    }

    @Test("Every Apple service resolves to its own bundled service asset")
    @MainActor
    func appleServicesUseDistinctAssets() throws {
        let providerIDs = [
            "apple_tv_plus", "apple_music", "icloud",
            "apple_arcade", "apple_fitness_plus", "apple_one",
        ]
        var resolutions: [ProviderIcon.Resolution] = []

        for providerID in providerIDs {
            let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
            #expect(provider.companyLogoFallbackDomain == nil)

            let resolution = ProviderIcon.resolution(for: provider)
            #expect(resolution == .asset("provider_\(providerID)"))
            resolutions.append(resolution)
        }

        #expect(resolutions == providerIDs.map { .asset("provider_\($0)") })
    }

    @Test(
        "Persisted service IDs resolve through the same bundled assets as Add",
        arguments: ["apple_music", "icloud"]
    )
    @MainActor
    func persistedServiceIdentityUsesCatalogAsset(providerID: String) throws {
        let item = RecurringItem(
            title: providerID,
            providerID: providerID,
            amount: 1,
            nextChargeDate: .now
        )

        let provider = try #require(item.providerTemplate)
        #expect(provider.id == providerID)
        #expect(ProviderIcon.resolution(for: provider) == .asset("provider_\(providerID)"))
    }

    @Test("Shared-domain service groups have explicit collision policies")
    @MainActor
    func sharedDomainGroupsDoNotCollapseAccidentally() throws {
        let amazonPrime = try #require(ProviderCatalog.template(forProviderID: "amazon_prime"))
        let kindle = try #require(ProviderCatalog.template(forProviderID: "kindle_unlimited"))
        #expect(amazonPrime.companyLogoFallbackDomain == nil)
        #expect(kindle.companyLogoFallbackDomain == nil)
        #expect(amazonPrime.letterMark == "AP")
        #expect(ProviderIcon.resolution(for: kindle) == .asset("provider_kindle_unlimited"))

        let oneDrive = try #require(ProviderCatalog.template(forProviderID: "onedrive"))
        let microsoft365 = try #require(ProviderCatalog.template(forProviderID: "microsoft_365"))
        #expect(oneDrive.companyLogoFallbackDomain == nil)
        #expect(ProviderIcon.resolution(for: oneDrive) == .asset("provider_onedrive"))
        #expect(originalSources(for: microsoft365) == ["https://www.microsoft365.com"])

        let notionAI = try #require(ProviderCatalog.template(forProviderID: "notion_ai"))
        let notion = try #require(ProviderCatalog.template(forProviderID: "notion"))
        #expect(notionAI.companyLogoFallbackDomain == nil)
        #expect(notion.companyLogoFallbackDomain == "notion.so")
        #expect(ProviderIcon.resolution(for: notionAI) == .asset("provider_notion_ai"))

        let youtubePremium = try #require(ProviderCatalog.template(forProviderID: "youtube_premium"))
        let youtubeMembership = try #require(ProviderCatalog.template(forProviderID: "youtube_membership"))
        #expect(ProviderIcon.resolution(for: youtubePremium) == .asset("provider_youtube_premium"))
        #expect(youtubeMembership.companyLogoFallbackDomain == "youtube.com")

        let mtsPremium = try #require(ProviderCatalog.template(forProviderID: "mts_premium"))
        let mts = try #require(ProviderCatalog.template(forProviderID: "mts"))
        #expect(ProviderIcon.resolution(for: mtsPremium) == .asset("provider_mts_premium"))
        #expect(ProviderIcon.resolution(for: mts) == .asset("provider_mts"))
        #expect(mtsPremium.companyLogoFallbackDomain == "mts.ru")
        #expect(mts.companyLogoFallbackDomain == "mts.ru")
    }

    private func originalSources(for provider: ProviderTemplate) -> [String] {
        ProviderLogoResolver.logoURLs(for: provider).compactMap { url in
            guard url.host() == "t1.gstatic.com" else {
                return url.absoluteString
            }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "url" }?
                .value
        }
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

// MARK: - Regional Pricing Identity Bridge Tests

@Suite("ProviderCatalog — Regional Pricing Identity")
struct ProviderCatalogRegionalPricingIdentityTests {

    private struct Manifest: Decodable {
        let market: String
        let prices: [ManifestPrice]
    }

    private struct ManifestPrice: Decodable {
        let providerID: String
        let tierID: String
        let channel: String
    }

    @Test("Declared catalog tiers construct exact provider-plan keys")
    func declaredTiersConstructExactProviderPlanKeys() throws {
        for provider in ProviderCatalog.all {
            for tier in provider.plans {
                let key = try provider.providerPlanKey(for: tier)

                #expect(key.providerID == provider.id)
                #expect(key.tierID == tier.id)
            }
        }
    }

    @Test("Catalog preserves the accepted provider and tier inventory")
    func catalogInventoryIsPreserved() throws {
        let providers = ProviderCatalog.all
        let tierCount = providers.reduce(0) { partialResult, provider in
            partialResult + provider.plans.count
        }
        let tierlessProviderCount = providers.filter { $0.plans.isEmpty }.count

        #expect(providers.count == 110)
        #expect(tierCount == 201)
        #expect(tierlessProviderCount == 31)
        #expect(providers.allSatisfy { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(providers.map(\.id).count == Set(providers.map(\.id)).count)

        for provider in providers {
            let tierIDs = provider.plans.map(\.id)
            #expect(tierIDs.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            #expect(tierIDs.count == Set(tierIDs).count)
        }
    }

    @Test("Catalog provider-plan keys are composite and collision-free")
    func providerPlanKeysAreCompositeAndCollisionFree() throws {
        let keys = try ProviderCatalog.all.flatMap { provider in
            try provider.plans.map { tier in
                try provider.providerPlanKey(for: tier)
            }
        }

        #expect(keys.count == Set(keys).count)

        let spotify = try #require(ProviderCatalog.template(forProviderID: "spotify"))
        let appleMusic = try #require(ProviderCatalog.template(forProviderID: "apple_music"))
        let spotifyIndividual = try #require(spotify.plans.first { $0.id == "individual" })
        let appleMusicIndividual = try #require(appleMusic.plans.first { $0.id == "individual" })
        let spotifyKey = try spotify.providerPlanKey(for: spotifyIndividual)
        let appleMusicKey = try appleMusic.providerPlanKey(for: appleMusicIndividual)

        #expect(spotifyKey != appleMusicKey)
    }

    @Test("Bridge is independent from provider and tier display names")
    func bridgeUsesStableIDsRatherThanDisplayNames() throws {
        var provider = ProviderTemplate(
            id: "stable_provider",
            displayName: "Localized provider name",
            category: .other
        )
        var tier = PlanTier(
            id: "stable_tier",
            name: "Localized tier name",
            referenceAmount: 12.99,
            billingCycle: .monthly
        )

        let originalKey = try provider.providerPlanKey(for: tier)
        provider.displayName = "Другое локализованное имя"
        tier.name = "Другой локализованный тариф"
        let renamedKey = try provider.providerPlanKey(for: tier)

        #expect(renamedKey == originalKey)
        #expect(originalKey.providerID == "stable_provider")
        #expect(originalKey.tierID == "stable_tier")
    }

    @Test("Production manifest identities map exactly once to catalog tiers")
    func productionManifestIdentitiesMapExactlyOnce() throws {
        let manifests = try productionManifests()
        let catalogKeys = try ProviderCatalog.all.flatMap { provider in
            try provider.plans.map { tier in
                try provider.providerPlanKey(for: tier)
            }
        }
        let keyCounts = Dictionary(catalogKeys.map { ($0, 1) }, uniquingKeysWith: +)
        let manifestPrices = manifests.flatMap(\.prices)
        let snapshot = try BundledRegionalPricingLoader().load(
            resourceNames: ["regional-pricing-us-v1", "regional-pricing-ru-v1"],
            in: applicationBundle()
        )

        #expect(manifestPrices.count == 27)

        for manifest in manifests {
            let market = try PricingMarket(countryCode: manifest.market)

            for price in manifest.prices {
                let provider = try #require(ProviderCatalog.template(forProviderID: price.providerID))
                let tier = try #require(provider.plans.first { $0.id == price.tierID })
                let key = try provider.providerPlanKey(for: tier)

                let expectedKey = try ProviderPlanKey(providerID: price.providerID, tierID: price.tierID)
                #expect(key == expectedKey)
                #expect(keyCounts[key] == 1)
                #expect(price.channel == PricingChannel.providerDirect.rawValue)

                let result = ResolveRegionalPlanPriceUseCase().execute(
                    key: RegionalPriceKey(providerPlan: key, market: market, channel: .providerDirect),
                    snapshot: snapshot,
                    asOf: .distantPast
                )
                guard case .available = result else {
                    Issue.record("Manifest key \(key.providerID)/\(key.tierID) did not resolve exactly")
                    continue
                }
            }
        }
    }

    @Test("Reference prices preserve Decimal data without Regional Pricing fallback")
    func referencePricesRemainLegacyCatalogData() throws {
        let appleMusic = try #require(ProviderCatalog.template(forProviderID: "apple_music"))
        let individual = try #require(appleMusic.plans.first { $0.id == "individual" })
        let expectedReferenceAmount = try #require(Decimal(string: "10.99", locale: Locale(identifier: "en_US_POSIX")))
        let referenceFieldNames = Set(Mirror(reflecting: individual.referencePrice).children.compactMap(\.label))

        #expect(individual.referencePrice.amount == expectedReferenceAmount)
        #expect(individual.referencePrice.currencyCode == nil)
        #expect(referenceFieldNames == Set(["amount", "currencyCode"]))

        let snapshot = try BundledRegionalPricingLoader().load(
            resourceNames: ["regional-pricing-us-v1", "regional-pricing-ru-v1"],
            in: applicationBundle()
        )
        let key = RegionalPriceKey(
            providerPlan: try appleMusic.providerPlanKey(for: individual),
            market: try PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: key,
            snapshot: snapshot,
            asOf: .distantPast
        )
        let manifestAmount = try #require(Decimal(string: "11.99", locale: Locale(identifier: "en_US_POSIX")))
        let manifestPrice = try #require(snapshot.price(for: key))

        #expect(result == .available(manifestPrice))
        #expect(manifestPrice.money.amount == manifestAmount)
        #expect(manifestPrice.money.amount != individual.referencePrice.amount)
    }

    private func productionManifests() throws -> [Manifest] {
        let bundle = try applicationBundle()

        return try ["regional-pricing-us-v1", "regional-pricing-ru-v1"].map { resourceName in
            let resourceURL = try #require(bundle.url(forResource: resourceName, withExtension: "json"))
            return try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: resourceURL))
        }
    }

    private func applicationBundle() throws -> Bundle {
        if Bundle.main.bundleIdentifier == "com.alexey.soren" {
            return Bundle.main
        }

        return try #require(Bundle.allBundles.first { bundle in
            bundle.bundleIdentifier == "com.alexey.soren"
        })
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
        #expect(results.count == ProviderCatalog.selectable.count)
    }

    @Test("Search with spaces only returns all")
    func spacesOnlyReturnsAll() async {
        let results = await repo.search(query: "   ")
        #expect(results.count == ProviderCatalog.selectable.count)
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
