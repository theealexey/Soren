import SwiftUI

// MARK: - Home Header View

/// Month label + 30-day forecast summary.
/// Sits at the top of the Home scroll content, above the landscape.
struct HomeHeaderView: View {

    let monthLabel: String
    let forecastLabel: String

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(monthLabel)
                .font(Typography.headline)
                .foregroundStyle(theme.primaryText)

            Spacer()

            Text(forecastLabel)
                .font(Typography.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.horizontal, Spacing.lg)
    }
}
