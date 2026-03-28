import SwiftUI

struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Подписки",
                systemImage: "list.bullet",
                description: Text("Все рекуррентные платежи в одном месте")
            )
            .navigationTitle("Подписки")
        }
    }
}

#Preview {
    LibraryPlaceholderView()
}
