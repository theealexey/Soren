import Foundation

// MARK: - User Preferences Repository

/// Persists user preferences via UserDefaults.
/// Intentionally a concrete struct — no protocol needed for simple key-value storage.
struct UserPreferencesRepository {

    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key {
        static let defaultCurrency = "soren.defaultCurrency"
        static let chargeAlertDays = "soren.chargeAlertDays"
        static let trialAlertDays  = "soren.trialAlertDays"
        static let appearanceMode  = "soren.appearanceMode"
    }

    // MARK: - Load

    func load() -> UserPreferences {
        let fallback = UserPreferences.default

        let currency = defaults.string(forKey: Key.defaultCurrency) ?? fallback.defaultCurrencyCode

        let chargeDays = defaults.object(forKey: Key.chargeAlertDays) != nil
            ? defaults.integer(forKey: Key.chargeAlertDays)
            : fallback.chargeAlertDays

        let trialDays = defaults.object(forKey: Key.trialAlertDays) != nil
            ? defaults.integer(forKey: Key.trialAlertDays)
            : fallback.trialAlertDays

        let modeRaw = defaults.string(forKey: Key.appearanceMode) ?? fallback.appearanceMode.rawValue
        let mode = AppearanceMode(rawValue: modeRaw) ?? fallback.appearanceMode

        return UserPreferences(
            defaultCurrencyCode: currency,
            chargeAlertDays: chargeDays,
            trialAlertDays: trialDays,
            appearanceMode: mode
        )
    }

    // MARK: - Save

    func save(_ prefs: UserPreferences) {
        defaults.set(prefs.defaultCurrencyCode, forKey: Key.defaultCurrency)
        defaults.set(prefs.chargeAlertDays, forKey: Key.chargeAlertDays)
        defaults.set(prefs.trialAlertDays, forKey: Key.trialAlertDays)
        defaults.set(prefs.appearanceMode.rawValue, forKey: Key.appearanceMode)
    }
}
