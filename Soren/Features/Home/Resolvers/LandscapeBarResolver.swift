import SwiftUI

// MARK: - Landscape Bar Resolver

/// Maps a BillingLandscapePoint + current selection to a concrete fill Color.
///
/// Receives AppTheme explicitly — never reads from environment.
/// This keeps the resolver pure and testable:
///   let color = LandscapeBarResolver(theme: .lightFog).fillColor(for: point, selection: nil)
struct LandscapeBarResolver {
    let theme: AppTheme

    // MARK: - Public Interface

    func fillColor(
        for point: BillingLandscapePoint,
        selection: BillingLandscapeSelection?
    ) -> Color {
        guard let selection else {
            return baseColor(for: point)
        }

        if Calendar.current.isDate(point.date, inSameDayAs: selection.date) {
            return theme.landscapeBarSelected
        }

        // All non-selected bars dim when a selection is active.
        return baseColor(for: point).opacity(0.35)
    }

    // MARK: - Private

    private func baseColor(for point: BillingLandscapePoint) -> Color {
        guard let normalizedHeight = point.normalizedHeight else {
            return theme.landscapeBarEmpty
        }

        switch normalizedHeight {
        case 0:          return theme.landscapeBarEmpty
        case ..<0.5:     return theme.landscapeBarBase
        case 0.5..<0.85: return theme.landscapeBarMid
        default:         return theme.landscapeBarPeak
        }
    }
}
