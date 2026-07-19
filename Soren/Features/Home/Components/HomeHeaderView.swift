import SwiftUI

// MARK: - Home Header View

/// Month label + 30-day forecast summary.
/// Sits at the top of the Home scroll content, above the landscape.
struct HomeHeaderView: View {

    let monthLabel: String
    let forecastLabel: String
    let exchangeRateNotice: HomeExchangeRateNotice

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Text(monthLabel)
                .font(Typography.headline)
                .foregroundStyle(theme.primaryText)

            Spacer(minLength: Spacing.sm)

            VStack(alignment: .trailing, spacing: Spacing.xxxs) {
                Text(forecastLabel)
                    .font(Typography.caption)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.trailing)

                if case .stale = exchangeRateNotice {
                    Label {
                        Text("По сохранённому курсу")
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .accessibilityHidden(true)
                    }
                    .font(Typography.footnote)
                    .foregroundStyle(ColorTokens.warning)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "По сохранённому курсу"))
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
    }
}
