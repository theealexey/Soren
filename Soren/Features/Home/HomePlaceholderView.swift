import SwiftUI

struct HomePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Главная",
                systemImage: "house.fill",
                description: Text("Центр управления подписками")
            )
            .navigationTitle("Главная")
        }
    }
}

#Preview {
    HomePlaceholderView()
}
