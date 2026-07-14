import Foundation

// MARK: - In-Memory Provider Catalog Repository

/// Provides access to the static provider catalog.
/// Data is in-memory — no persistence needed, catalog is bundled with the app.
/// Thread-safe because the catalog is immutable after init.
final class InMemoryProviderCatalogRepository: ProviderCatalogRepository {

    private let providers: [ProviderTemplate]

    init(providers: [ProviderTemplate] = ProviderCatalog.all) {
        self.providers = providers
    }

    private var selectableProviders: [ProviderTemplate] {
        providers.filter(\.isSelectable)
    }

    func fetchAll() async -> [ProviderTemplate] {
        selectableProviders
    }

    func fetchByRegion(_ region: ProviderTemplate.Region) async -> [ProviderTemplate] {
        selectableProviders.filter { $0.region == region }
    }

    func fetchByCategory(_ category: ItemCategory) async -> [ProviderTemplate] {
        selectableProviders.filter { $0.category == category }
    }

    func search(query: String) async -> [ProviderTemplate] {
        selectableProviders.filter { $0.matches(query) }
    }

    /// Direct lookup intentionally includes legacy templates used by persisted subscriptions.
    func fetch(id: String) async -> ProviderTemplate? {
        providers.first { $0.id == id }
    }
}
