import SwiftUI

struct AnalyticsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Analytics",
                systemImage: "chart.bar.fill",
                description: Text("Spending insights and forecasts")
            )
            .navigationTitle("Analytics")
        }
    }
}

#Preview {
    AnalyticsPlaceholderView()
}
