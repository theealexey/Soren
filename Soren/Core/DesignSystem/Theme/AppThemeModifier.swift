import SwiftUI

// MARK: - App Theme Modifier

/// Reads the system color scheme (already driven by AppearanceMode via
/// `.preferredColorScheme` in SorenApp) and injects the matching AppTheme
/// instance into the SwiftUI environment.
///
/// Apply once at the root of the view hierarchy, after `.preferredColorScheme`.
struct AppThemeModifier: ViewModifier {
    let mode: AppearanceMode
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.appTheme, resolvedTheme)
    }

    // `.preferredColorScheme` in SorenApp already flips `colorScheme` to the
    // correct value for .light and .dark modes, so a single dark-check suffices.
    private var resolvedTheme: AppTheme {
        colorScheme == .dark ? .darkMineral : .lightFog
    }
}
