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
    let notificationPermissionCoordinator: NotificationPermissionCoordinator
    let applicationSettingsOpener: any ApplicationSettingsOpening
    let notificationObservation: NotificationReconciliationObservation
    #if DEBUG
    let notificationDiagnosticsProvider: NotificationDiagnosticsProvider?
    #endif

    /// Incremented whenever recurring items are mutated.
    /// Views observe this to know when to reload their ViewModels.
    var itemsVersion: Int = 0

    init(modelContext: ModelContext) {
        let prefs      = UserPreferencesRepository()
        let repos      = RepositoryContainer(context: modelContext)
        let notificationCenter = UNUserNotificationCenterClient()
        let reconciler = NotificationReconciler(center: notificationCenter)
        let notificationObservation = NotificationReconciliationObservation()
        self.repositories = repos
        self.providerCatalog = InMemoryProviderCatalogRepository()
        self.preferences = prefs
        self.exchangeRateProvider = OpenExchangeRateProvider()
        self.regionalPricingSnapshotResult = Self.loadRegionalPricing()
        let refreshCoordinator = NotificationRefreshCoordinator(
            repository: repos.recurringItems,
            reconciler: reconciler,
            observation: notificationObservation
        )
        self.notificationRefreshCoordinator = refreshCoordinator
        self.notificationPermissionCoordinator = NotificationPermissionCoordinator(
            center: notificationCenter,
            refreshCoordinator: refreshCoordinator,
            observation: notificationObservation
        )
        self.applicationSettingsOpener = UIApplicationSettingsOpener()
        self.notificationObservation = notificationObservation
        #if DEBUG
        self.notificationDiagnosticsProvider = NotificationDiagnosticsProvider(
            center: notificationCenter,
            observation: notificationObservation
        )
        #endif
    }

    /// For SwiftUI Previews and tests — fully in-memory, no disk persistence.
    init(
        repositories: RepositoryContainer,
        providerCatalog: any ProviderCatalogRepository = InMemoryProviderCatalogRepository(),
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        regionalPricingSnapshotResult: Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> = AppContainer.loadRegionalPricing(),
        notificationCenter: any NotificationCenterClient = UNUserNotificationCenterClient(),
        notificationReconciler: (any NotificationReconciling)? = nil,
        applicationSettingsOpener: any ApplicationSettingsOpening = UIApplicationSettingsOpener()
    ) {
        self.repositories = repositories
        self.providerCatalog = providerCatalog
        self.preferences = preferences
        self.exchangeRateProvider = exchangeRateProvider
        self.regionalPricingSnapshotResult = regionalPricingSnapshotResult
        let reconciler = notificationReconciler ?? NotificationReconciler(center: notificationCenter)
        let notificationObservation = NotificationReconciliationObservation()
        let refreshCoordinator = NotificationRefreshCoordinator(
            repository: repositories.recurringItems,
            reconciler: reconciler,
            observation: notificationObservation
        )
        self.notificationRefreshCoordinator = refreshCoordinator
        self.notificationPermissionCoordinator = NotificationPermissionCoordinator(
            center: notificationCenter,
            refreshCoordinator: refreshCoordinator,
            observation: notificationObservation
        )
        self.applicationSettingsOpener = applicationSettingsOpener
        self.notificationObservation = notificationObservation
        #if DEBUG
        self.notificationDiagnosticsProvider = nil
        #endif
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            permissionManager: notificationPermissionCoordinator,
            settingsOpener: applicationSettingsOpener
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
