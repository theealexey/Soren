import SwiftUI

extension AppearanceMode {
    /// Maps the domain appearance preference to a SwiftUI `ColorScheme`.
    /// Lives in Core (presentation layer) so Domain stays SwiftUI-free.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    /// Localized label shown in the Appearance Picker in Settings.
    var displayName: String {
        switch self {
        case .system: String(localized: "Системная")
        case .light:  String(localized: "Светлая")
        case .dark:   String(localized: "Тёмная")
        }
    }
}
