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

    init(modelContext: ModelContext) {
        self.repositories = RepositoryContainer(context: modelContext)
        self.providerCatalog = InMemoryProviderCatalogRepository()
    }

    /// For SwiftUI Previews and tests — fully in-memory, no disk persistence.
    init(
        repositories: RepositoryContainer,
        providerCatalog: any ProviderCatalogRepository = InMemoryProviderCatalogRepository()
    ) {
        self.repositories = repositories
        self.providerCatalog = providerCatalog
    }
}
