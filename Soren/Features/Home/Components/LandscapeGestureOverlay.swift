import SwiftUI

// MARK: - Landscape Gesture Overlay

/// Transparent drag/tap overlay that sits above the chart bars.
///
/// DragGesture(minimumDistance: 0) captures both taps and scrubs.
/// The overlay converts the gesture x-position to a point index,
/// resolves the corresponding date, and calls back to the ViewModel.
///
/// onRelease fires HapticEngine.selection() once per gesture end.
struct LandscapeGestureOverlay: View {

    let pointCount: Int
    let onSelectIndex: (Int) -> Void
    let onRelease: () -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let index = indexFor(x: value.location.x, width: proxy.size.width)
                            onSelectIndex(index)
                        }
                        .onEnded { _ in
                            // Do NOT call onSelectIndex here — it would re-trigger the
                            // toggle and immediately deselect whatever onChanged just set.
                            onRelease()
                        }
                )
        }
    }

    private func indexFor(x: CGFloat, width: CGFloat) -> Int {
        guard pointCount > 0, width > 0 else { return 0 }
        let slotWidth = width / CGFloat(pointCount)
        let raw = Int(floor(x / slotWidth))
        return min(max(raw, 0), pointCount - 1)
    }
}
