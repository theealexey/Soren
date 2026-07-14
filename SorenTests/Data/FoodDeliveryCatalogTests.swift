import Foundation
import Testing
@testable import Soren

@Suite("Food and delivery catalog exclusions")
struct FoodDeliveryCatalogTests {

    private static let removedProviderIDs = ["delivery_club", "yandex_delivery"]

    @Test("Transactional delivery services are absent from the complete curated catalog")
    func removedEntriesDoNotRemainResolvable() {
        for providerID in Self.removedProviderIDs {
            #expect(!ProviderCatalog.all.contains { $0.id == providerID })
            #expect(ProviderCatalog.template(forProviderID: providerID) == nil)
        }
    }

    @Test("Transactional delivery services are absent from Add, search, and Popular")
    func removedEntriesAreNotSelectableOrSearchable() async {
        let repository = InMemoryProviderCatalogRepository()
        let selectable = await repository.fetchAll()
        let popular = selectable.filter { $0.tags.contains("popular") }
        let queries = [
            "Delivery Club", "Деливери", "Яндекс Еда", "Яндекс Лавка",
        ]

        for providerID in Self.removedProviderIDs {
            #expect(!selectable.contains { $0.id == providerID })
            #expect(!popular.contains { $0.id == providerID })
        }

        for query in queries {
            let results = await repository.search(query: query)
            #expect(
                results.allSatisfy { !Self.removedProviderIDs.contains($0.id) },
                "Removed provider found for query: \(query)"
            )
        }
    }

    @Test("Yandex Plus and Yandex 360 remain selectable")
    func validYandexSubscriptionsRemainAvailable() async {
        let repository = InMemoryProviderCatalogRepository()
        let selectable = await repository.fetchAll()

        #expect(selectable.contains { $0.id == "yandex_plus" })
        #expect(selectable.contains { $0.id == "yandex_360" })
        #expect((await repository.search(query: "яндекс плюс")).contains { $0.id == "yandex_plus" })
        #expect((await repository.search(query: "yandex 360")).contains { $0.id == "yandex_360" })
    }

    @Test("Removed providers leave no bundled asset directories")
    func removedProvidersHaveNoOrphanedAssets() {
        let providersDirectory = repositoryRoot
            .appendingPathComponent("Soren/Resources/Assets.xcassets/Providers", isDirectory: true)

        for providerID in Self.removedProviderIDs {
            let assetDirectory = providersDirectory
                .appendingPathComponent("provider_\(providerID).imageset", isDirectory: true)
            #expect(
                !FileManager.default.fileExists(atPath: assetDirectory.path),
                "Orphaned provider asset: provider_\(providerID)"
            )
        }
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
