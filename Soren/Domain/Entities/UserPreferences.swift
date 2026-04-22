import Foundation

// MARK: - User Preferences

/// Persistent user settings for the app.
/// Stored in UserDefaults, not SwiftData (lightweight key-value, not domain data).
struct UserPreferences: Sendable {
    var defaultCurrencyCode: String
    var defaultChargeReminder: ChargeReminderOption
    var chargeAlertDays: Int
    var trialAlertDays: Int

    static let `default` = UserPreferences(
        defaultCurrencyCode: "RUB",
        defaultChargeReminder: .threeDaysBefore,
        chargeAlertDays: 3,
        trialAlertDays: 3
    )
}

// MARK: - Appearance Mode

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: String(localized: "Системная")
        case .light:  String(localized: "Светлая")
        case .dark:   String(localized: "Тёмная")
        }
    }
}
