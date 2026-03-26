import SwiftUI

struct HomePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Dashboard",
                systemImage: "house.fill",
                description: Text("Your recurring payments command center")
            )
            .navigationTitle("Home")
        }
    }
}

#Preview {
    HomePlaceholderView()
}
