import SwiftUI

// MARK: - Shadow Tokens

/// Elevation-based shadow system.
/// Shadows adapt automatically to light/dark via system behavior.
enum ShadowTokens {
    /// Subtle lift for interactive elements (buttons, chips).
    /// Cold blue-black tint signals depth without warmth.
    static let sm = ShadowStyle(
        color: Color(red: 0.0, green: 0.07, blue: 0.16).opacity(0.08),
        radius: 3,
        x: 0,
        y: 1
    )

    /// Standard card elevation.
    static let md = ShadowStyle(
        color: Color(red: 0.0, green: 0.07, blue: 0.16).opacity(0.12),
        radius: 8,
        x: 0,
        y: 3
    )

    /// Prominent elevation for floating elements, modals.
    static let lg = ShadowStyle(
        color: Color(red: 0.0, green: 0.07, blue: 0.16).opacity(0.18),
        radius: 16,
        x: 0,
        y: 6
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
