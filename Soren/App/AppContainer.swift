import SwiftUI
import SwiftData

/// Central dependency injection container — assembled once at app launch,
/// injected into the SwiftUI environment via `.environmentObject()`.
///
/// This is the single point where all dependencies are wired together.
/// Features access repositories through this container, never directly.
@MainActor @Observable
final class AppContainer {
    let repositories: RepositoryContainer
    let providerCatalog: any ProviderCatalogRepository
    let preferences: UserPreferencesRepository
    let exchangeRateProvider: any ExchangeRateProvider

    /// Incremented whenever recurring items are mutated.
    /// Views observe this to know when to reload their ViewModels.
    var itemsVersion: Int = 0

    init(modelContext: ModelContext) {
        self.repositories = RepositoryContainer(context: modelContext)
        self.providerCatalog = InMemoryProviderCatalogRepository()
        self.preferences = UserPreferencesRepository()
        self.exchangeRateProvider = OpenExchangeRateProvider()
    }

    /// For SwiftUI Previews and tests — fully in-memory, no disk persistence.
    init(
        repositories: RepositoryContainer,
        providerCatalog: any ProviderCatalogRepository = InMemoryProviderCatalogRepository(),
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider()
    ) {
        self.repositories = repositories
        self.providerCatalog = providerCatalog
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
    }
}
