import SwiftUI

struct CalendarPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Календарь",
                systemImage: "calendar",
                description: Text("Визуализация расписания платежей")
            )
            .navigationTitle("Календарь")
        }
    }
}

#Preview {
    CalendarPlaceholderView()
}
