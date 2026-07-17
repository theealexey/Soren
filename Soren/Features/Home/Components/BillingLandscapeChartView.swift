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
        let chartPoints = Self.numericPoints(from: points)

        Chart(chartPoints) { point in
            if let normalizedHeight = point.normalizedHeight {
                BarMark(
                    x: .value(String(localized: "День"), point.id),
                    y: .value(String(localized: "Сумма"), max(normalizedHeight, 0.04))
                )
                .foregroundStyle(resolver.fillColor(for: point, selection: selection))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.hairline))
            }
        }
        .chartYScale(domain: 0...1)
        .chartYAxis(.hidden)
        .chartXAxis(.hidden)
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity)
        }
        .animation(MotionTokens.snappy, value: selection?.date)
    }

    /// Keeps no-charge day marks in the established chart while ensuring an
    /// all-unavailable financial window cannot render as a zero-value landscape.
    static func numericPoints(from points: [BillingLandscapePoint]) -> [BillingLandscapePoint] {
        let hasAvailableCharge = points.contains {
            $0.chargeCount > 0 && $0.normalizedHeight != nil
        }
        let hasUnavailableCharge = points.contains {
            $0.chargeCount > 0 && $0.normalizedHeight == nil
        }

        guard hasAvailableCharge || !hasUnavailableCharge else {
            return []
        }

        return points.filter { $0.normalizedHeight != nil }
    }
}
