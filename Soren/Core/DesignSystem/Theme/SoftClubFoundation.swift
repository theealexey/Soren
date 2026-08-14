import SwiftUI

// MARK: - Soft Club Semantic Roles

/// Semantic color roles shared by the accepted Design Lock and the migrated
/// production Overview.
enum SoftClubColor {
    static let canvas = Color("Colors/SoftClubCanvas")
    static let secondaryCanvas = Color("Colors/SoftClubSecondaryCanvas")
    static let surface = Color("Colors/SoftClubSurface")
    static let elevatedSurface = Color("Colors/SoftClubElevatedSurface")
    static let glassControlSurface = Color("Colors/SoftClubGlassControl")

    static let textPrimary = Color("Colors/SoftClubTextPrimary")
    static let textSecondary = Color("Colors/SoftClubTextSecondary")
    static let textTertiary = Color("Colors/SoftClubTextTertiary")
    static let subtleSeparator = Color("Colors/SoftClubSeparator")
    static let subtleBorder = Color("Colors/SoftClubBorder")

    static let icyPrimary = Color("Colors/SoftClubIcyPrimary")
    static let mutedSecondary = Color("Colors/SoftClubMutedSecondary")

    /// Rare brand emphasis. It is intentionally distinct from destructive UI.
    static let signatureRed = Color("Colors/SoftClubSignatureRed")
    static let destructive = Color("Colors/SoftClubDestructive")
    static let success = Color("Colors/SoftClubSuccess")
    static let warning = Color("Colors/SoftClubWarning")
}

// MARK: - Native Glass Capability

private struct SoftClubInteractiveGlassModifier<ControlShape: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let shape: ControlShape
    let forceOpaque: Bool

    func body(content: Content) -> some View {
        if forceOpaque || reduceTransparency || colorSchemeContrast == .increased {
            content.background(SoftClubColor.glassControlSurface, in: shape)
        } else if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: shape)
        } else {
            content.background(.thinMaterial, in: shape)
        }
    }
}

extension View {
    /// Applies native interactive glass when available, with an opaque
    /// accessibility fallback. Call only on an interactive control after its
    /// caller has supplied layout and other visual decisions.
    func softClubInteractiveGlass<ControlShape: Shape>(
        in shape: ControlShape,
        forceOpaque: Bool = false
    ) -> some View {
        modifier(SoftClubInteractiveGlassModifier(shape: shape, forceOpaque: forceOpaque))
    }
}
