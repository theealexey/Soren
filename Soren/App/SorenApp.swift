import SwiftUI
import SwiftData

@main
struct SorenApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([])
            let config = ModelConfiguration(
                "Soren",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            container = try ModelContainer(for: schema, configurations: [config])
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
