import Foundation

// MARK: - User Preferences Repository

/// Persists user preferences via UserDefaults.
/// Intentionally a concrete struct — no protocol needed for simple key-value storage.
/// Note: appearanceMode is owned by AppState and persisted separately.
struct UserPreferencesRepository {

    private nonisolated(unsafe) let defaults: UserDefaults
    private let initialDeviceRegionCode: String?

    init(
        defaults: UserDefaults = .standard,
        initialDeviceRegionCode: String? = Locale.current.region?.identifier
    ) {
        self.defaults = defaults
        self.initialDeviceRegionCode = initialDeviceRegionCode
    }

    // MARK: - Keys

    private enum Key {
        static let defaultCurrency       = "soren.defaultCurrency"
        static let defaultChargeReminder = "soren.defaultChargeReminder"
        static let chargeAlertDays       = "soren.chargeAlertDays"
        static let trialAlertDays        = "soren.trialAlertDays"
        static let pricingMarket         = "soren.pricingMarket"
    }

    // MARK: - Load

    func load() -> UserPreferences {
        let fallback = UserPreferences.default

        let currency = defaults.string(forKey: Key.defaultCurrency) ?? fallback.defaultCurrencyCode
        let pricingMarket = persistedPricingMarket() ?? seedInitialPricingMarket()

        let chargeReminder = defaults.string(forKey: Key.defaultChargeReminder)
            .flatMap(ChargeReminderOption.init) ?? fallback.defaultChargeReminder

        let chargeDays = defaults.object(forKey: Key.chargeAlertDays) != nil
            ? defaults.integer(forKey: Key.chargeAlertDays)
            : fallback.chargeAlertDays

        let trialDays = defaults.object(forKey: Key.trialAlertDays) != nil
            ? defaults.integer(forKey: Key.trialAlertDays)
            : fallback.trialAlertDays

        return UserPreferences(
            defaultCurrencyCode: currency,
            pricingMarket: pricingMarket,
            defaultChargeReminder: chargeReminder,
            chargeAlertDays: chargeDays,
            trialAlertDays: trialDays
        )
    }

    // MARK: - Save

    func save(_ prefs: UserPreferences) {
        defaults.set(prefs.defaultCurrencyCode,            forKey: Key.defaultCurrency)
        defaults.set(prefs.pricingMarket.countryCode,      forKey: Key.pricingMarket)
        defaults.set(prefs.defaultChargeReminder.rawValue, forKey: Key.defaultChargeReminder)
        defaults.set(prefs.chargeAlertDays,                forKey: Key.chargeAlertDays)
        defaults.set(prefs.trialAlertDays,                 forKey: Key.trialAlertDays)
    }

    private func persistedPricingMarket() -> PricingMarket? {
        guard let rawValue = defaults.string(forKey: Key.pricingMarket) else {
            return nil
        }

        return try? PricingMarket(countryCode: rawValue)
    }

    private func seedInitialPricingMarket() -> PricingMarket {
        let market = UserPreferences.initialPricingMarket(
            deviceRegionCode: initialDeviceRegionCode
        )
        defaults.set(market.countryCode, forKey: Key.pricingMarket)
        return market
    }
}
