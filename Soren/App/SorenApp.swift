import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try SorenModelContainer.production()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
