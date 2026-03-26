import SwiftUI

// MARK: - Shadow Tokens

/// Elevation-based shadow system.
/// Shadows adapt automatically to light/dark via system behavior.
enum ShadowTokens {
    /// Subtle lift for interactive elements (buttons, chips).
    static let sm = ShadowStyle(
        color: .black.opacity(0.06),
        radius: 4,
        x: 0,
        y: 2
    )

    /// Standard card elevation.
    static let md = ShadowStyle(
        color: .black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 4
    )

    /// Prominent elevation for floating elements, modals.
    static let lg = ShadowStyle(
        color: .black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 8
    )
}

// MARK: - Shadow Style

struct ShadowStyle: Equatable, Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extension

extension View {
    func elevation(_ style: ShadowStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}
