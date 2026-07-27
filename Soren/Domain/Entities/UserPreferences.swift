import Foundation

// MARK: - User Preferences

/// Persistent user settings for the app.
/// Stored in UserDefaults, not SwiftData (lightweight key-value, not domain data).
struct UserPreferences: Sendable {
    var defaultCurrencyCode: String
    var pricingMarket: PricingMarket = UserPreferences.defaultPricingMarket
    var defaultChargeReminder: ChargeReminderOption
    var chargeAlertDays: Int
    var trialAlertDays: Int

    static let defaultPricingMarket = requiredPricingMarket(countryCode: "US")

    static let `default` = UserPreferences(
        defaultCurrencyCode: "RUB",
        pricingMarket: defaultPricingMarket,
        defaultChargeReminder: .threeDaysBefore,
        chargeAlertDays: 3,
        trialAlertDays: 3
    )

    /// Device region is used only when no persisted pricing market exists yet.
    /// It is intentionally independent from the reporting currency and UI locale.
    static func initialPricingMarket(deviceRegionCode: String?) -> PricingMarket {
        let normalizedRegion = deviceRegionCode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        return requiredPricingMarket(countryCode: normalizedRegion == "RU" ? "RU" : "US")
    }

    private static func requiredPricingMarket(countryCode: String) -> PricingMarket {
        guard let market = try? PricingMarket(countryCode: countryCode) else {
            preconditionFailure("Built-in pricing market must be a valid ISO country code")
        }
        return market
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark
}
