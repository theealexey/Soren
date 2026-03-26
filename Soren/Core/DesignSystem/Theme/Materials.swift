import SwiftUI

// MARK: - Material Tokens

/// Surface material system.
/// Uses native SwiftUI materials that adapt to light/dark automatically.
/// On iOS 26+, system chrome (tab bar, nav bar) gets Liquid Glass for free.
enum MaterialTokens {

    /// Thin blur for overlays on top of content (e.g., floating action button backdrop).
    static let thinOverlay: some ShapeStyle = .ultraThinMaterial

    /// Standard blur for cards that overlay scrollable content.
    static let regularOverlay: some ShapeStyle = .regularMaterial

    /// Thick blur for prominent surfaces like bottom sheets.
    static let thickOverlay: some ShapeStyle = .thickMaterial

    /// Bar material matching system navigation/tab bar appearance.
    static let bar: some ShapeStyle = .bar
}

// MARK: - Glass Card Modifier

extension View {
    /// Applies a frosted glass card style — works as a premium
    /// surface that subtly shows content beneath.
    func glassCard(cornerRadius: CGFloat = CornerRadius.large) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }
}
