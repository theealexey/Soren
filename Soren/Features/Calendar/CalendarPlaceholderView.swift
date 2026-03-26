import SwiftUI

struct CalendarPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendar",
                systemImage: "calendar",
                description: Text("Visualize your payment timeline")
            )
            .navigationTitle("Calendar")
        }
    }
}

#Preview {
    CalendarPlaceholderView()
}
