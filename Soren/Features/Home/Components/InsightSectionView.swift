import SwiftUI

// MARK: - Insight Section View

/// Flat list of InsightRowModel rows with hairline separators.
/// No section header — rows are self-explanatory via their label column.
struct InsightSectionView: View {

    let insights: [InsightRowModel]

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            hairline

            ForEach(insights) { row in
                InsightRowView(model: row)

                if row.id != insights.last?.id {
                    hairline
                        .padding(.horizontal, Spacing.lg)
                }
            }

            hairline
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
    }
}
