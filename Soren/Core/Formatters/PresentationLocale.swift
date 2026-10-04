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

/// UI carrier dates and billing civil days are deliberately separate boundaries.
enum BillingDatePresentation {
    static func today(now: Date = .now, in timeZone: TimeZone = .current) throws -> CivilDate {
        try BillingCivilDay.civilDate(containing: now, in: timeZone)
    }
    static func pickerCarrier(for day: CivilDate, in timeZone: TimeZone) throws -> Date {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: DateComponents(
            year: day.year, month: day.month, day: day.day, hour: 12
        )), try BillingCivilDay.civilDate(containing: date, in: timeZone) == day else {
            throw BillingCivilDayError.unrepresentableCivilDate(day)
        }
        return date
    }

    static func day(fromPickerCarrier date: Date, in timeZone: TimeZone) throws -> CivilDate {
        try BillingCivilDay.civilDate(containing: date, in: timeZone)
    }

    static func string(
        from canonicalDate: Date, template: String = "dMMMM",
        locale: Locale = PresentationLocale.current
    ) throws -> String {
        _ = try BillingCivilDay.civilDate(fromCanonicalDate: canonicalDate)
        let formatter = PresentationLocale.dateFormatter(
            template: template, locale: locale, calendar: BillingCivilDay.calendar
        )
        formatter.timeZone = .gmt
        return formatter.string(from: canonicalDate)
    }
}
