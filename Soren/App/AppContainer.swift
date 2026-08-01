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
    let regionalPricingSnapshotResult: Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError>
    let notificationRefreshCoordinator: NotificationRefreshCoordinator

    /// Incremented whenever recurring items are mutated.
    /// Views observe this to know when to reload their ViewModels.
    var itemsVersion: Int = 0

    init(modelContext: ModelContext) {
        let prefs      = UserPreferencesRepository()
        let repos      = RepositoryContainer(context: modelContext)
        let reconciler = NotificationReconciler(center: UNUserNotificationCenterClient())
        self.repositories = repos
        self.providerCatalog = InMemoryProviderCatalogRepository()
        self.preferences = prefs
        self.exchangeRateProvider = OpenExchangeRateProvider()
        self.regionalPricingSnapshotResult = Self.loadRegionalPricing()
        self.notificationRefreshCoordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            reconciler: reconciler
        )
    }

    /// For SwiftUI Previews and tests — fully in-memory, no disk persistence.
    init(
        repositories: RepositoryContainer,
        providerCatalog: any ProviderCatalogRepository = InMemoryProviderCatalogRepository(),
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        regionalPricingSnapshotResult: Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> = AppContainer.loadRegionalPricing(),
        notificationReconciler: any NotificationReconciling = NotificationReconciler(
            center: UNUserNotificationCenterClient()
        )
    ) {
        self.repositories = repositories
        self.providerCatalog = providerCatalog
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
        self.regionalPricingSnapshotResult = regionalPricingSnapshotResult
        self.notificationRefreshCoordinator = NotificationRefreshCoordinator(
            repository: repositories.recurringItems,
            reconciler: notificationReconciler
        )
    }

    static func loadRegionalPricing(
        in bundle: Bundle = .main
    ) -> Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> {
        do {
            return .success(try BundledRegionalPricingLoader().load(
                resourceNames: [
                    "regional-pricing-us-v1",
                    "regional-pricing-ru-v1"
                ],
                in: bundle
            ))
        } catch let error as BundledRegionalPricingLoaderError {
            return .failure(error)
        } catch {
            return .failure(.resourceUnreadable("RegionalPricing"))
        }
    }
}
