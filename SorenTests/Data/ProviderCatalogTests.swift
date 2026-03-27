import Testing
import Foundation
@testable import Soren

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
}
