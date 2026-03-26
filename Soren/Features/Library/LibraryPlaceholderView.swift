import SwiftUI

struct LibraryPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Library",
                systemImage: "list.bullet",
                description: Text("All your recurring items in one place")
            )
            .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryPlaceholderView()
}
