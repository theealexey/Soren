import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            Group {
                if let appContainer = appState.appContainer,
                   let container = appState.modelContainer {
                    RootView()
                        .environment(appContainer)
                        .environment(appState)
                        .modelContainer(container)
                } else {
                    StoreRecoveryView { appState.recoverWithReset() }
                }
            }
            .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
    }
}
