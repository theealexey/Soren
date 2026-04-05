import SwiftUI

// MARK: - App Theme

/// Semantic visual tokens for the Billing Landscape Home screen.
/// Feature views read these via `@Environment(\.appTheme)`.
/// Never reference raw Color values inside feature views.
///
/// Parallel to ColorTokens — does not replace it.
/// Existing non-Home screens continue using ColorTokens.
struct AppTheme {

    // MARK: Backgrounds

    let screenBackground: Color

    // MARK: Text

    let primaryText: Color
    let secondaryText: Color
    let tertiaryText: Color

    // MARK: Structure

    let hairline: Color

    // MARK: Landscape Bars

    let landscapeBarBase: Color
    let landscapeBarMid: Color
    let landscapeBarPeak: Color
    let landscapeBarSelected: Color
    let landscapeBarEmpty: Color

    // MARK: Semantic States

    let warningTint: Color
    let quietTint: Color
}

// MARK: - Light Fog

extension AppTheme {

    /// Foggy off-white. Cool, diffuse, matte.
    /// Bar hue: washed steel blue, opacity-encoded.
    static let lightFog = AppTheme(
        screenBackground:     Color(hex: "#F0F2F4"),
        primaryText:          Color(hex: "#191C22"),
        secondaryText:        Color(hex: "#6B7380"),
        tertiaryText:         Color(hex: "#9BA3AE"),
        hairline:             Color(hex: "#D0D4DA"),
        landscapeBarBase:     Color(hex: "#A8BAC8").opacity(0.45),
        landscapeBarMid:      Color(hex: "#A8BAC8").opacity(0.72),
        landscapeBarPeak:     Color(hex: "#A8BAC8"),
        landscapeBarSelected: Color(hex: "#3D5A72"),
        landscapeBarEmpty:    Color(hex: "#A8BAC8").opacity(0.18),
        warningTint:          Color(hex: "#9A7A54"),
        quietTint:            Color(hex: "#5A8472")
    )
}

// MARK: - Dark Mineral

extension AppTheme {

    /// Deep slate, slightly blue-cast. Not black — mineral stone quality.
    /// Bars lift in luminance upward; low values nearly disappear into the background.
    static let darkMineral = AppTheme(
        screenBackground:     Color(hex: "#0E1014"),
        primaryText:          Color(hex: "#DDE2E8"),
        secondaryText:        Color(hex: "#6A7885"),
        tertiaryText:         Color(hex: "#3E4A55"),
        hairline:             Color(hex: "#1A2028"),
        landscapeBarBase:     Color(hex: "#8FAFC8").opacity(0.20),
        landscapeBarMid:      Color(hex: "#8FAFC8").opacity(0.45),
        landscapeBarPeak:     Color(hex: "#8FAFC8").opacity(0.78),
        landscapeBarSelected: Color(hex: "#AECBE0"),
        landscapeBarEmpty:    Color(hex: "#8FAFC8").opacity(0.08),
        warningTint:          Color(hex: "#B08A62"),
        quietTint:            Color(hex: "#527A68")
    )
}
