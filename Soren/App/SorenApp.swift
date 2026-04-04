import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    private let container: ModelContainer
    @State private var appContainer: AppContainer
    @AppStorage("soren.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    init() {
        func makeAppContainer(_ mc: ModelContainer) -> AppContainer {
            AppContainer(modelContext: mc.mainContext)
        }

        if let mc = try? SorenModelContainer.production() {
            container = mc
            _appContainer = State(initialValue: makeAppContainer(mc))
            return
        }

        // Store may be corrupted (e.g., failed iCloud sync). Delete and retry.
        SorenModelContainer.deleteProductionStore()
        if let mc = try? SorenModelContainer.production() {
            container = mc
            _appContainer = State(initialValue: makeAppContainer(mc))
            return
        }

        // Last resort: in-memory only. User data is lost for this session but the app runs.
        let mc = try! SorenModelContainer.inMemory()
        container = mc
        _appContainer = State(initialValue: makeAppContainer(mc))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appContainer)
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(container)
    }

    private var colorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme
    }
}
