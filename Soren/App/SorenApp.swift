import SwiftUI
import SwiftData

#if !(DEBUG && SOFT_CLUB_DESIGN_LOCK_HOST)
@main
#endif
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
                } else if appState.preparationState == .civilDateBlocked {
                    VStack(spacing: Spacing.lg) {
                        Text("Не удалось загрузить данные")
                        Button(String(localized: "Повторить")) { appState.prepare() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if appState.preparationState == .storeUnavailable {
                    StoreRecoveryView { appState.recoverWithReset() }
                } else {
                    ProgressView()
                }
            }
            .preferredColorScheme(appState.appearanceMode.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
                .receive(on: DispatchQueue.main)) { _ in
                Task { @MainActor in
                    appState.reconcileTemporalEnvironment()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                .receive(on: DispatchQueue.main)) { _ in
                Task { @MainActor in
                    appState.reconcileTemporalEnvironment()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
                .receive(on: DispatchQueue.main)) { _ in
                Task { @MainActor in
                    appState.reconcileTemporalEnvironment()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
                .receive(on: DispatchQueue.main)) { _ in
                Task { @MainActor in
                    appState.reconcileTemporalEnvironment()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            appState.sceneActivityChanged(isActive: phase == .active)
        }
    }
}
