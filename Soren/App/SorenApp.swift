import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let appContainer = appState.appContainer,
                   let container = appState.modelContainer {
                    RootView()
                        .environment(appContainer)
                        .environment(appState)
                        .modelContainer(container)
                        .modifier(AppThemeModifier(mode: appState.appearanceMode))
                } else {
                    StoreRecoveryView { appState.recoverWithReset() }
                }
            }
            .preferredColorScheme(appState.appearanceMode.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.appContainer?.notificationRefreshCoordinator.didBecomeActive()
            }
        }
    }
}
