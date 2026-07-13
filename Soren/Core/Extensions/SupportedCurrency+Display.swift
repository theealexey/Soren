import Foundation

// MARK: - SupportedCurrency Display

/// Presentation-layer extension that produces a locale-aware display name
/// for a currency without leaking localization logic into the Domain entity.
///
/// Uses Foundation's built-in currency-name database (`Locale`) rather than
/// a parallel xcstrings table — covers all currencies and all locales
/// automatically, with the stored English `name` as a fallback.
extension SupportedCurrency {

    /// The full currency name in the user's current locale.
    /// Example: "российский рубль" (ru), "Russian Ruble" (en), "Russischer Rubel" (de).
    var localizedName: String {
        PresentationLocale.current.localizedString(forCurrencyCode: code) ?? name
    }
}
