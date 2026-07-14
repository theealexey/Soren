import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Soren

@Suite("Dating category and catalog")
struct DatingCatalogTests {

    private static let globalIDs = ["tinder", "bumble", "hinge", "badoo", "feeld", "her"]
    private static let regionalIDs = ["twinby", "mamba", "pure"]
    private static let newIDs = globalIDs + regionalIDs

    @Test("Dating category keeps existing persisted raw values and appends the new case")
    func categoryRawValuesRemainBackwardCompatible() {
        let existingRawValues = [
            "video", "music", "books", "cloud", "productivity", "aiTools",
            "shopping", "banking", "mobile", "internet", "health", "games",
            "vpn", "food", "education", "creators", "other",
        ]

        #expect(ItemCategory.allCases.dropLast().map(\.rawValue) == existingRawValues)
        #expect(ItemCategory.allCases.last == .dating)
        #expect(ItemCategory.dating.rawValue == "dating")
    }

    @Test("Dating category has Russian and English presentation values")
    func categoryLocalizationIsComplete() throws {
        let englishBundle = try localizationBundle("en")
        let russianBundle = try localizationBundle("ru")

        #expect(
            String(localized: "Знакомства", bundle: englishBundle, locale: Locale(identifier: "en"))
                == "Dating"
        )
        #expect(
            String(localized: "Знакомства", bundle: russianBundle, locale: Locale(identifier: "ru"))
                == "Знакомства"
        )
        #expect(ItemCategory.dating.systemIconName == "heart.fill")
    }

    @Test("Dating and Health use distinct semantic color tokens")
    @MainActor
    func categoryColorsAreSemanticallyDistinct() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let dating = UIColor(ItemCategory.dating.color).resolvedColor(with: traits)
            let datingToken = UIColor(ColorTokens.categoryDating).resolvedColor(with: traits)
            let health = UIColor(ItemCategory.health.color).resolvedColor(with: traits)
            let healthToken = UIColor(ColorTokens.categoryHealth).resolvedColor(with: traits)

            #expect(dating.isEqual(datingToken))
            #expect(health.isEqual(healthToken))
            #expect(!dating.isEqual(health))
        }
    }

    @Test("Existing dating services are reclassified without moving creator services")
    func categoryAssignmentsAreCorrect() throws {
        let grindr = try #require(ProviderCatalog.template(forProviderID: "grindr"))
        let hornet = try #require(ProviderCatalog.template(forProviderID: "hornet"))
        let discord = try #require(ProviderCatalog.template(forProviderID: "discord_nitro"))
        let reddit = try #require(ProviderCatalog.template(forProviderID: "reddit_premium"))

        #expect(grindr.category == .dating)
        #expect(hornet.category == .dating)
        #expect(discord.category != .dating)
        #expect(reddit.category != .dating)
    }

    @Test("Approved dating IDs are unique and stay in their requested catalog packs")
    func newProviderIDsAreUnique() {
        let global = Set(ProviderCatalog.global.map(\.id))
        let regional = Set(ProviderCatalog.russia.map(\.id))

        #expect(Set(Self.newIDs).count == Self.newIDs.count)
        #expect(Set(Self.globalIDs).isSubset(of: global))
        #expect(Set(Self.regionalIDs).isSubset(of: regional))
        #expect(global.isDisjoint(with: regional))
    }

    @Test("New dating providers use explicit service identities without unverified pricing")
    @MainActor
    func newProvidersResolveToBundledServiceAssets() throws {
        for providerID in Self.newIDs {
            let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
            let assetName = "provider_\(providerID)"

            #expect(provider.category == .dating)
            #expect(provider.plans.isEmpty)
            #expect(provider.serviceLogoSourceURL != nil)
            #expect(provider.companyLogoFallbackDomain == nil)
            #expect(UIImage(named: assetName) != nil, "Missing declared asset: \(assetName)")
            #expect(ProviderIcon.resolution(for: provider) == .asset(assetName))
        }
    }

    @Test("Dating raster assets meet the large Add tile quality floor")
    func datingRasterAssetsMeetQualityFloor() throws {
        let providersDirectory = repositoryRoot
            .appendingPathComponent("Soren/Resources/Assets.xcassets/Providers", isDirectory: true)

        for providerID in Self.newIDs {
            let assetName = "provider_\(providerID)"
            let imageURL = providersDirectory
                .appendingPathComponent("\(assetName).imageset", isDirectory: true)
                .appendingPathComponent("logo.jpg")
            let image = try #require(UIImage(contentsOfFile: imageURL.path))
            let cgImage = try #require(image.cgImage)
            let dimensions = "\(cgImage.width)×\(cgImage.height)"

            #expect(cgImage.width == cgImage.height, "\(assetName): \(dimensions)")
            #expect(cgImage.width >= 256, "\(assetName): \(dimensions)")
            #expect(cgImage.height >= 256, "\(assetName): \(dimensions)")
        }
    }

    @Test("Every approved dating provider is searchable")
    func searchFindsEveryNewProvider() async {
        let repository = InMemoryProviderCatalogRepository()

        for providerID in Self.newIDs {
            let results = await repository.search(query: providerID)
            #expect(results.contains { $0.id == providerID }, "Search missed \(providerID)")
        }
    }

    @Test("Dating category participates in Analytics grouping")
    @MainActor
    func datingParticipatesInAnalyticsGrouping() async throws {
        let suiteName = "DatingCatalogTests.Analytics.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = UserPreferencesRepository(defaults: defaults)
        preferences.save(UserPreferences(
            defaultCurrencyCode: "RUB",
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))

        let item = RecurringItem(
            title: "Tinder",
            providerID: "tinder",
            category: .dating,
            amount: 10,
            currencyCode: "USD",
            nextChargeDate: .now
        )
        let repository = DatingAnalyticsRepository(items: [item])
        let rateDate = Date(timeIntervalSince1970: 1_700_000_000)
        let rateProvider = StaticExchangeRateProvider(rates: ExchangeRates(
            base: "USD",
            date: rateDate,
            rates: ["RUB": 100],
            fetchedAt: rateDate
        ))
        let viewModel = AnalyticsViewModel(
            getActiveItems: GetActiveItems(repository: repository),
            preferences: preferences,
            exchangeRateProvider: rateProvider
        )

        viewModel.loadLocalData()
        await viewModel.refreshCurrencyAggregation(revision: viewModel.aggregationRevision)

        #expect(viewModel.screenState.categoryBreakdown.count == 1)
        #expect(viewModel.screenState.categoryBreakdown.first?.category == .dating)
        #expect(viewModel.screenState.categoryBreakdown.first?.itemCount == 1)
        #expect(viewModel.screenState.categoryBreakdown.first?.monthlyTotal == 1_000)
        #expect(viewModel.screenState.monthlyAggregation?.total?.currencyCode == "RUB")
    }

    @Test("New dating providers never emit Clearbit URLs")
    func newProvidersDoNotUseClearbit() throws {
        for providerID in Self.newIDs {
            let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
            let urls = ProviderLogoResolver.logoURLs(for: provider)

            #expect(!urls.isEmpty)
            #expect(urls.allSatisfy { $0.host() != "logo.clearbit.com" })
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func localizationBundle(_ languageCode: String) throws -> Bundle {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}

@MainActor
private final class DatingAnalyticsRepository: RecurringItemRepository {
    private let items: [RecurringItem]

    init(items: [RecurringItem]) {
        self.items = items
    }

    func fetchAll() throws -> [RecurringItem] { items }
    func fetchActive() throws -> [RecurringItem] { items }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { items }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        items.filter { $0.category == category }
    }
    func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
    func save(_ item: RecurringItem) throws {}
    func update(_ item: RecurringItem) throws {}
    func delete(id: UUID) throws {}
    func saveAll(_ items: [RecurringItem]) throws {}
    func deleteAll() throws {}
}
