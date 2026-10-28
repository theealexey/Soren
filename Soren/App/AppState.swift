import Foundation
import SwiftData

// MARK: - App Launch State

/// Owns the SwiftData container, AppContainer, and appearance mode for the app lifetime.
/// Separating this from `SorenApp` (a struct) allows mutating state after
/// a user-initiated store recovery without needing to restart the process.
@Observable
@MainActor
final class AppState {
    enum PreparationState { case preparing, ready, civilDateBlocked, storeUnavailable }
    private(set) var preparationState: PreparationState = .preparing
    private(set) var modelContainer: ModelContainer?
    private(set) var appContainer: AppContainer?
    private(set) var preparationError: Error?
    private let openStore: () throws -> ModelContainer
    private let bootstrap: (ModelContainer, TimeZone) throws -> Void
    private let validate: (RepositoryContainer) throws -> Void
    private let makeAppContainer: (ModelContainer, RepositoryContainer) -> AppContainer
    private let migrationTimeZone: TimeZone
    private var sceneIsActive = false
    private let now: () -> Date
    private let runtimeTimeZone: () -> TimeZone
    private(set) var temporalError: Error?
    private(set) var temporalFingerprint: TemporalFingerprint?

    struct TemporalFingerprint: Equatable {
        let day: CivilDate
        let timeZoneIdentifier: String
        let secondsFromGMT: Int
    }

    /// Signals are hints; only a changed, successfully sampled context invalidates UI.
    func reconcileTemporalEnvironment() {
        guard let appContainer else { return }
        do {
            let instant = now()
            let sourceZone = runtimeTimeZone()
            let identifier = sourceZone.identifier
            guard let zone = TimeZone(identifier: identifier) else {
                throw BillingCivilDayError.invalidInstant(instant)
            }
            let fingerprint = TemporalFingerprint(
                day: try BillingCivilDay.civilDate(containing: instant, in: zone),
                timeZoneIdentifier: identifier,
                secondsFromGMT: zone.secondsFromGMT(for: instant)
            )
            temporalError = nil
            guard fingerprint != temporalFingerprint else { return }
            let hadBaseline = temporalFingerprint != nil
            temporalFingerprint = fingerprint
            if hadBaseline { appContainer.invalidateTemporalContext() }
        } catch {
            temporalError = error
        }
    }

    /// Single source of truth for the app's color scheme preference.
    /// Changes are persisted to UserDefaults immediately (no debounce needed).
    var appearanceMode: AppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "soren.appearanceMode")
        }
    }

    init(
        openStore: @escaping () throws -> ModelContainer = { try SorenModelContainer.production() },
        interpretationTimeZone: TimeZone = .current,
        now: @escaping () -> Date = { .now },
        runtimeTimeZone: @escaping () -> TimeZone = { .current },
        bootstrap: @escaping (ModelContainer, TimeZone) throws -> Void = {
            try LegacyBillingDateProvenanceBootstrap().execute(container: $0, interpretationTimeZone: $1)
        },
        validate: @escaping (RepositoryContainer) throws -> Void = { _ = try $0.recurringItems.fetchAll() },
        makeAppContainer: @escaping (ModelContainer, RepositoryContainer) -> AppContainer = {
            AppContainer(modelContext: $0.mainContext, repositories: $1)
        }
    ) {
        self.now = now
        self.runtimeTimeZone = runtimeTimeZone
        self.openStore = openStore
        self.bootstrap = bootstrap
        self.validate = validate
        self.makeAppContainer = makeAppContainer
        self.migrationTimeZone = interpretationTimeZone
        if let raw = UserDefaults.standard.string(forKey: "soren.appearanceMode"),
           let mode = AppearanceMode(rawValue: raw) {
            appearanceMode = mode
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--subscriptions-light") {
            appearanceMode = .light
        } else if ProcessInfo.processInfo.arguments.contains("--subscriptions-dark") {
            appearanceMode = .dark
        }

        if let scenario = DebugHomeScenario.requested(in: ProcessInfo.processInfo.arguments) {
            do {
                let container = try SorenModelContainer.inMemory()
                modelContainer = container
                let appContainer = AppContainer(modelContext: container.mainContext)
                try appContainer.repositories.recurringItems.saveAll(scenario.items)
                var preferences = appContainer.preferences.load()
                preferences.defaultCurrencyCode = "RUB"
                appContainer.preferences.save(preferences)
                let repositories = appContainer.repositories
                try validate(repositories)
                self.appContainer = appContainer
                preparationState = .ready
                reconcileTemporalEnvironment()
                return
            } catch {
                preparationError = error
                preparationState = modelContainer == nil ? .storeUnavailable : .civilDateBlocked
            }
            return
        }
        #endif

        prepare()
    }

    /// Retry retains both the opened store and the once-captured interpretation policy.
    func prepare() {
        preparationState = .preparing
        preparationError = nil
        appContainer = nil
        temporalFingerprint = nil
        temporalError = nil
        if modelContainer == nil {
            do { modelContainer = try openStore() }
            catch {
                preparationError = error
                preparationState = .storeUnavailable
                return
            }
        }
        guard let container = modelContainer else { return }
        do {
            try bootstrap(container, migrationTimeZone)
            let repositories = RepositoryContainer(context: container.mainContext)
            try validate(repositories)
            let readyContainer = makeAppContainer(container, repositories)
            appContainer = readyContainer
            preparationState = .ready
            reconcileTemporalEnvironment()
            if sceneIsActive { readyContainer.notificationRefreshCoordinator.didBecomeActive() }
        } catch {
            preparationError = error
            preparationState = .civilDateBlocked
        }
    }

    func sceneActivityChanged(isActive: Bool) {
        sceneIsActive = isActive
        if isActive, preparationState == .ready {
            reconcileTemporalEnvironment()
            appContainer?.notificationRefreshCoordinator.didBecomeActive()
        }
    }

    /// Called only after the user confirms data reset in StoreRecoveryView.
    func recoverWithReset() {
        guard preparationState == .storeUnavailable else { return }
        SorenModelContainer.deleteProductionStore()
        modelContainer = nil
        prepare()
    }
}
