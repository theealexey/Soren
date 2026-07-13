import SwiftUI

// MARK: - Landscape Axis View

/// Two-tick date axis below the billing landscape chart.
/// Shows only the first and last date in the window — enough context,
/// no visual noise. Monospaced digits prevent layout shifts.
struct LandscapeAxisView: View {

    let points: [BillingLandscapePoint]

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack {
            Text(startLabel)
                .font(Typography.axisLabel)
                .foregroundStyle(theme.tertiaryText)

            Spacer()

            Text(endLabel)
                .font(Typography.axisLabel)
                .foregroundStyle(theme.tertiaryText)
        }
        .padding(.horizontal, Spacing.lg)
    }

    private var startLabel: String {
        points.first.map { Self.formatter.string(from: $0.date) } ?? ""
    }

    private var endLabel: String {
        points.last.map { Self.formatter.string(from: $0.date) } ?? ""
    }

    private static let formatter: DateFormatter = {
        PresentationLocale.dateFormatter(template: "MMM d")
    }()
}
