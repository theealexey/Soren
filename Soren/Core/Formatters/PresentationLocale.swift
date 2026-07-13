import Foundation

// MARK: - Presentation Locale

/// Resolves linguistic formatting from the app's selected localization while
/// retaining the user's regional conventions. Non-View formatters use this
/// instead of `Locale.current`, whose language can differ from the per-app
/// language selected in Settings.
enum PresentationLocale {

    static var current: Locale {
        resolved(
            appLanguageIdentifier: Bundle.main.preferredLocalizations.first,
            regionalLocale: .current
        )
    }

    static func resolved(
        appLanguageIdentifier: String?,
        regionalLocale: Locale
    ) -> Locale {
        guard
            let appLanguageIdentifier,
            let languageCode = Locale(identifier: appLanguageIdentifier).language.languageCode
        else {
            return regionalLocale
        }

        var components = Locale.Components(languageCode: languageCode)
        components.region = regionalLocale.region
        components.numberingSystem = regionalLocale.numberingSystem
        return Locale(components: components)
    }

    static func dateFormatter(
        template: String,
        locale: Locale = current,
        calendar: Calendar? = nil
    ) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
