import SwiftUI

// MARK: - Billing Landscape Container View

/// Composes the chart, gesture overlay, and axis label into one unit.
///
/// The gesture overlay sits on top of the chart in a ZStack.
/// Index → Date resolution happens here so the overlay stays generic.
/// Haptic feedback fires on gesture end (drag release / tap lift).
struct BillingLandscapeContainerView: View {

    let points: [BillingLandscapePoint]
    let selection: BillingLandscapeSelection?
    let onSelectDate: (Date) -> Void

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                BillingLandscapeChartView(points: points, selection: selection)
                    .frame(height: 120)
                    .padding(.horizontal, Spacing.lg)

                LandscapeGestureOverlay(
                    pointCount: points.count,
                    onSelectIndex: { index in
                        guard index < points.count else { return }
                        onSelectDate(points[index].date)
                    },
                    onRelease: {
                        HapticEngine.selection()
                    }
                )
                .padding(.horizontal, Spacing.lg)
            }
            .frame(height: 120)

            LandscapeAxisView(points: points)
        }
    }
}
