import Foundation

// MARK: - User Preferences Repository

/// Persists user preferences via UserDefaults.
/// Intentionally a concrete struct — no protocol needed for simple key-value storage.
/// Note: appearanceMode is owned by AppState and persisted separately.
struct UserPreferencesRepository {

    private nonisolated(unsafe) let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Keys

    private enum Key {
        static let defaultCurrency      = "soren.defaultCurrency"
        static let defaultChargeReminder = "soren.defaultChargeReminder"
        static let defaultTrialReminder  = "soren.defaultTrialReminder"
        static let chargeAlertDays      = "soren.chargeAlertDays"
        static let trialAlertDays       = "soren.trialAlertDays"
    }

    // MARK: - Load

    func load() -> UserPreferences {
        let fallback = UserPreferences.default

        let currency = defaults.string(forKey: Key.defaultCurrency) ?? fallback.defaultCurrencyCode

        let chargeReminder = defaults.string(forKey: Key.defaultChargeReminder)
            .flatMap(ChargeReminderOption.init) ?? fallback.defaultChargeReminder

        let trialReminder = defaults.string(forKey: Key.defaultTrialReminder)
            .flatMap(TrialReminderOption.init) ?? fallback.defaultTrialReminder

        let chargeDays = defaults.object(forKey: Key.chargeAlertDays) != nil
            ? defaults.integer(forKey: Key.chargeAlertDays)
            : fallback.chargeAlertDays

        let trialDays = defaults.object(forKey: Key.trialAlertDays) != nil
            ? defaults.integer(forKey: Key.trialAlertDays)
            : fallback.trialAlertDays

        return UserPreferences(
            defaultCurrencyCode: currency,
            defaultChargeReminder: chargeReminder,
            defaultTrialReminder: trialReminder,
            chargeAlertDays: chargeDays,
            trialAlertDays: trialDays
        )
    }

    // MARK: - Save

    func save(_ prefs: UserPreferences) {
        defaults.set(prefs.defaultCurrencyCode,            forKey: Key.defaultCurrency)
        defaults.set(prefs.defaultChargeReminder.rawValue, forKey: Key.defaultChargeReminder)
        defaults.set(prefs.defaultTrialReminder.rawValue,  forKey: Key.defaultTrialReminder)
        defaults.set(prefs.chargeAlertDays,                forKey: Key.chargeAlertDays)
        defaults.set(prefs.trialAlertDays,                 forKey: Key.trialAlertDays)
    }
}
