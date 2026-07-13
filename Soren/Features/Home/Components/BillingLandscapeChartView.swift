import SwiftUI
import Charts

// MARK: - Billing Landscape Chart View

/// Swift Charts bar chart for the 30-day billing landscape.
///
/// Visual rules:
///   • Constant bar width — peak emphasis via color token, never width
///   • No axes, no grid lines — shape/form only; exact values surface in callout
///   • Selection state dims all non-selected bars to 35% opacity (via LandscapeBarResolver)
///   • Bar corner radius: CornerRadius.hairline (2pt) — barely-there rounding
struct BillingLandscapeChartView: View {

    let points: [BillingLandscapePoint]
    let selection: BillingLandscapeSelection?

    @Environment(\.appTheme) private var theme

    var body: some View {
        let resolver = LandscapeBarResolver(theme: theme)

        Chart(points) { point in
            BarMark(
                x: .value(String(localized: "День"), point.id),
                y: .value(String(localized: "Сумма"), max(point.normalizedHeight, 0.04))  // floor for empty-day visibility
            )
            .foregroundStyle(resolver.fillColor(for: point, selection: selection))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.hairline))
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity)
        }
        .animation(MotionTokens.snappy, value: selection?.date)
    }
}
