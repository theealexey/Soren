import SwiftData

// MARK: - App Launch State

/// Owns the SwiftData container and AppContainer for the lifetime of the app.
/// Separating this from `SorenApp` (a struct) allows mutating state after
/// a user-initiated store recovery without needing to restart the process.
@Observable
@MainActor
final class AppState {
    var modelContainer: ModelContainer?
    var appContainer: AppContainer?

    init() {
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
