import SwiftUI

// MARK: - AppTheme Environment Key

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .lightFog
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
