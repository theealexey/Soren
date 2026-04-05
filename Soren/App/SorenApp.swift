import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    @State private var appState = AppState()
    @AppStorage("soren.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some Scene {
        WindowGroup {
            Group {
                if let appContainer = appState.appContainer,
                   let container = appState.modelContainer {
                    RootView()
                        .environment(appContainer)
                        .modelContainer(container)
                } else {
                    StoreRecoveryView { appState.recoverWithReset() }
                }
            }
            .preferredColorScheme(AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme)
        }
    }
}
