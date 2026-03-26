import SwiftUI

struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Settings",
                systemImage: "gearshape.fill",
                description: Text("Appearance, currency, notifications & more")
            )
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsPlaceholderView()
}
