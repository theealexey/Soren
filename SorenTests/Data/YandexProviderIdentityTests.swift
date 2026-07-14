import Foundation
import Testing
import UIKit
@testable import Soren

@Suite("Yandex curated provider identities")
struct YandexProviderIdentityTests {

    private static let expectedAssets = [
        "yandex_plus": "provider_yandex_plus",
        "yandex_disk": "provider_yandex_disk",
        "yandex_360": "provider_yandex_360",
    ]

    private static let expectedRemoteSources = [
        "yandex_plus": "https://avatars.mds.yandex.net/get-media-infra/3756502/d787faef9f2f25928f2306d47a099b9bc2de99f1/orig",
        "yandex_disk": "https://yastatic.net/s3/tuning/static/pages/brand-services/versions/0.0.10/assets/downloads/%D0%B8%D0%BA%D0%BE%D0%BD%D0%BA%D0%B0_%D0%B4%D0%B8%D1%81%D0%BA.png",
        "yandex_360": "https://yastatic.net/s3/tuning/static/pages/brand-logo/versions/0.0.12/assets/downloads/main_icon.png",
    ]

    @Test("Yandex 360 is a separate regional cloud provider")
    func yandex360CatalogFieldsAreCorrect() throws {
        let provider = try #require(ProviderCatalog.template(forProviderID: "yandex_360"))

        #expect(provider.displayName == "Яндекс 360")
        #expect(provider.category == .cloud)
        #expect(provider.region == .russia)
        #expect(provider.suggestedCurrencyCode == "RUB")
        #expect(provider.plans.isEmpty)
        #expect(provider.isSelectable)
        #expect(provider.serviceLogoSourceURL?.absoluteString == Self.expectedRemoteSources["yandex_360"])
        #expect(provider.companyLogoFallbackDomain == nil)
    }

    @Test("Yandex services resolve by stable ID to distinct bundled assets")
    @MainActor
    func yandexServicesUseDistinctBundledAssets() throws {
        for (providerID, assetName) in Self.expectedAssets {
            let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
            let resolution = ProviderIcon.resolution(for: provider)

            #expect(UIImage(named: assetName) != nil, "Missing bundled asset: \(assetName)")
            #expect(resolution == .asset(assetName))
        }

        #expect(Set(Self.expectedAssets.values).count == Self.expectedAssets.count)
    }

    @Test("New Yandex raster assets meet the large Add tile quality floor")
    func yandexRasterAssetsMeetQualityFloor() throws {
        let providersDirectory = repositoryRoot
            .appendingPathComponent("Soren/Resources/Assets.xcassets/Providers", isDirectory: true)

        for assetName in ["provider_yandex_disk", "provider_yandex_360"] {
            let imageURL = providersDirectory
                .appendingPathComponent("\(assetName).imageset", isDirectory: true)
                .appendingPathComponent("logo.png")
            let image = try #require(UIImage(contentsOfFile: imageURL.path))
            let cgImage = try #require(image.cgImage)
            let dimensions = "\(cgImage.width)×\(cgImage.height)"

            #expect(cgImage.width == cgImage.height, "\(assetName): \(dimensions)")
            #expect(cgImage.width >= 256, "\(assetName): \(dimensions)")
            #expect(cgImage.height >= 256, "\(assetName): \(dimensions)")
        }
    }

    @Test("Yandex Disk is legacy-resolvable but excluded from Add and search")
    @MainActor
    func yandexDiskIsLegacyOnly() async throws {
        let repository = InMemoryProviderCatalogRepository()
        let selectable = await repository.fetchAll()

        let yandex360Results = await repository.search(query: "yandex 360")
        let yandexDiskResults = await repository.search(query: "яндекс диск")
        let popularProviders = selectable.filter { $0.tags.contains("popular") }
        let legacyTemplate = try #require(await repository.fetch(id: "yandex_disk"))

        #expect(selectable.contains { $0.id == "yandex_360" })
        #expect(!selectable.contains { $0.id == "yandex_disk" })
        #expect(yandex360Results.contains { $0.id == "yandex_360" })
        #expect(yandexDiskResults.isEmpty)
        #expect(!yandex360Results.contains { $0.id == "yandex_disk" })
        #expect(!popularProviders.contains { $0.id == "yandex_disk" })
        #expect(!legacyTemplate.isSelectable)

        let persistedItem = RecurringItem(
            title: "Яндекс Диск",
            providerID: "yandex_disk",
            category: .cloud,
            amount: 1,
            currencyCode: "RUB",
            nextChargeDate: .now
        )
        let resolvedTemplate = try #require(persistedItem.providerTemplate)

        #expect(persistedItem.providerID == "yandex_disk")
        #expect(resolvedTemplate.id == "yandex_disk")
        #expect(resolvedTemplate.displayName == "Яндекс Диск")
        #expect(resolvedTemplate.category == .cloud)
        #expect(resolvedTemplate.region == .russia)
        #expect(ProviderIcon.resolution(for: resolvedTemplate) == .asset("provider_yandex_disk"))
    }

    @Test("Yandex service sources are direct images and never collapse to a company favicon")
    func yandexServicesUseDirectServiceSources() throws {
        for (providerID, expectedSource) in Self.expectedRemoteSources {
            let provider = try #require(ProviderCatalog.template(forProviderID: providerID))
            let urls = ProviderLogoResolver.logoURLs(for: provider)

            #expect(provider.serviceLogoSourceURL?.absoluteString == expectedSource)
            #expect(provider.companyLogoFallbackDomain == nil)
            #expect(urls.map(\.absoluteString) == [expectedSource])
            #expect(urls.allSatisfy { $0.host() != "logo.clearbit.com" })
            #expect(urls.allSatisfy { $0.host() != "t1.gstatic.com" })
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
