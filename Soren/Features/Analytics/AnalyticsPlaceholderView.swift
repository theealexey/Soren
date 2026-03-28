import SwiftUI

struct AnalyticsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Аналитика",
                systemImage: "chart.bar.fill",
                description: Text("Анализ расходов и прогнозы")
            )
            .navigationTitle("Аналитика")
        }
    }
}

#Preview {
    AnalyticsPlaceholderView()
}
