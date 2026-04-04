import SwiftUI

// MARK: - Quick Insights Section

/// Dashboard section with actionable financial observations.
struct QuickInsightsSection: View {
    let insights: [InsightsBuilder.InsightData]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Аналитика"))

            ForEach(insights, id: \.title) { insight in
                InsightCard(
                    icon: insight.icon,
                    title: insight.title,
                    subtitle: insight.subtitle,
                    severity: insight.severity
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QuickInsightsSection(
        insights: [
            InsightsBuilder.InsightData(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "2 просроченных списания"),
                subtitle: String(localized: "Проверьте способы оплаты"),
                severity: .critical
            ),
            InsightsBuilder.InsightData(
                icon: "calendar.badge.clock",
                title: String(localized: "4 списания на этой неделе"),
                subtitle: nil,
                severity: .info
            ),
        ]
    )
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
