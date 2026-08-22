import Foundation
import SwiftData

// MARK: - App Launch State

/// Owns the SwiftData container, AppContainer, and appearance mode for the app lifetime.
/// Separating this from `SorenApp` (a struct) allows mutating state after
/// a user-initiated store recovery without needing to restart the process.
@Observable
@MainActor
final class AppState {
    var modelContainer: ModelContainer?
    var appContainer: AppContainer?

    /// Single source of truth for the app's color scheme preference.
    /// Changes are persisted to UserDefaults immediately (no debounce needed).
    var appearanceMode: AppearanceMode = .system {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "soren.appearanceMode")
        }
    }

    init() {
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

        if let scenario = DebugHomeScenario.requested(in: ProcessInfo.processInfo.arguments),
           let container = try? SorenModelContainer.inMemory() {
            let appContainer = AppContainer(modelContext: container.mainContext)
            do {
                try appContainer.repositories.recurringItems.saveAll(scenario.items)
                var preferences = appContainer.preferences.load()
                preferences.defaultCurrencyCode = "RUB"
                appContainer.preferences.save(preferences)
                modelContainer = container
                self.appContainer = appContainer
                return
            } catch {
                // Fall through to the production store if DEBUG fixture setup fails.
            }
        }
        #endif

        if let mc = try? SorenModelContainer.production() {
            modelContainer = mc
            appContainer = AppContainer(modelContext: mc.mainContext)
        }
        // If modelContainer is nil here, RootView is replaced by StoreRecoveryView.
        // The user must explicitly consent before any data is deleted.
    }

    /// Called only after the user confirms data reset in StoreRecoveryView.
    func recoverWithReset() {
        SorenModelContainer.deleteProductionStore()
        let mc = (try? SorenModelContainer.production())
            ?? (try? SorenModelContainer.inMemory())
        guard let mc else { return }
        modelContainer = mc
        appContainer = AppContainer(modelContext: mc.mainContext)
    }
}
