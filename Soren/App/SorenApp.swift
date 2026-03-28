import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    private let container: ModelContainer
    @State private var appContainer: AppContainer
    @AppStorage("soren.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue

    init() {
        do {
            let modelContainer = try SorenModelContainer.production()
            self.container = modelContainer
            self._appContainer = State(
                initialValue: AppContainer(modelContext: modelContainer.mainContext)
            )
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
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
        switch AppearanceMode(rawValue: appearanceModeRaw) {
        case .light: .light
        case .dark:  .dark
        default:     nil
        }
    }
}
