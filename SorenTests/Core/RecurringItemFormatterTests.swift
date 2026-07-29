import Testing
import Foundation
@testable import Soren

// MARK: - Recurring Item Formatter Tests (Adversarial)

/// Tests the shared RecurringItemFormatter — single source of truth
/// for display helpers previously duplicated across ViewModels.

@Suite("RecurringItemFormatter")
struct RecurringItemFormatterTests {

    // MARK: - Helpers

    private func makeItem(
        billingCycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        nextCharge: Date? = nil,
        trialEndDate: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            amount: 299,
            currencyCode: "RUB",
            billingCycle: billingCycle,
            nextChargeDate: nextCharge ?? Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            trialEndDate: trialEndDate,
            status: status
        )
    }

    // MARK: - cycleLabel

    @Test("cycleLabel maps all BillingCycle variants")
    func cycleLabelMapping() {
        #expect(RecurringItemFormatter.cycleLabel(for: .weekly) == .weekly)
        #expect(RecurringItemFormatter.cycleLabel(for: .monthly) == .monthly)
        #expect(RecurringItemFormatter.cycleLabel(for: .annual) == .yearly)

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .quarterly) {
            #expect(text == String(localized: "кв"))
        } else {
            Issue.record("Quarterly should produce .custom")
        }

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .semiannual) {
            #expect(text == String(localized: "п/г"))
        } else {
            Issue.record("Semiannual should produce .custom")
        }

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .custom(days: 14)) {
            #expect(text == String(localized: "\(14)д"))
        } else {
            Issue.record("Custom(14) should produce .custom")
        }
    }

    @Test("cycleLabel custom with 1 day")
    func cycleLabelSingleDay() {
        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .custom(days: 1)) {
            #expect(text == String(localized: "\(1)д"))
        } else {
            Issue.record("Custom(1) should produce .custom")
        }
    }

    // MARK: - badge

    @Test("badge returns correct type for each status")
    func badgeMapping() {
        let trial = makeItem(status: .trial,
                             trialEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now))
        #expect(RecurringItemFormatter.badge(for: trial) == .trial)

        let failed = makeItem(status: .failed)
        #expect(RecurringItemFormatter.badge(for: failed) == .failed)

        let paused = makeItem(status: .paused)
        #expect(RecurringItemFormatter.badge(for: paused) == .paused)

        let dueSoon = makeItem(status: .dueSoon)
        #expect(RecurringItemFormatter.badge(for: dueSoon) == .dueSoon)

        let dueToday = makeItem(status: .dueToday)
        #expect(RecurringItemFormatter.badge(for: dueToday) == .dueSoon)

        // Active monthly — no badge
        let active = makeItem(billingCycle: .monthly, status: .active)
        #expect(RecurringItemFormatter.badge(for: active) == nil)

        // Active annual — gets .annual badge
        let annual = makeItem(billingCycle: .annual, status: .active)
        #expect(RecurringItemFormatter.badge(for: annual) == .annual)
    }

    @Test("badge returns nil for cancelled items")
    func badgeCancelledNil() {
        let cancelled = makeItem(status: .cancelled)
        #expect(RecurringItemFormatter.badge(for: cancelled) == nil)
    }

    // MARK: - chargeSubtitle

    @Test("chargeSubtitle handles edge days correctly")
    func chargeSubtitleEdgeCases() throws {
        let now = Date.now

        let today = makeItem(nextCharge: now)
        let todaySubtitle = RecurringItemFormatter.chargeSubtitle(for: today)
        #expect(todaySubtitle == String(localized: "Списание сегодня"))

        let overdue = makeItem(
            status: .paused,
            nextCharge: now.addingTimeInterval(-10 * 24 * 60 * 60)
        )
        let overdueSubtitle = RecurringItemFormatter.chargeSubtitle(for: overdue)
        let overdueDays = try #require(
            Calendar.current.dateComponents([.day], from: Date.now, to: overdue.nextChargeDate).day
        )
        #expect(overdueSubtitle == String(localized: "Дата списания была \(abs(overdueDays)) дн. назад"))

        let future = makeItem(nextCharge: now.addingTimeInterval(10 * 24 * 60 * 60 + 12 * 60 * 60))
        let futureSubtitle = RecurringItemFormatter.chargeSubtitle(for: future)
        let futureDays = try #require(
            Calendar.current.dateComponents([.day], from: Date.now, to: future.nextChargeDate).day
        )
        #expect(futureSubtitle == String(localized: "Через \(futureDays) дн."))
    }

    @Test("chargeSubtitle uses tomorrow label for one full day remaining")
    func chargeSubtitleTomorrow() {
        let tomorrow = Date.now.addingTimeInterval(36 * 60 * 60)
        let item = makeItem(nextCharge: tomorrow)
        let subtitle = RecurringItemFormatter.chargeSubtitle(for: item)
        #expect(subtitle == String(localized: "Списание завтра"))
    }

    // MARK: - subtitle (full status handling)

    @Test("subtitle handles all statuses")
    func subtitleAllStatuses() {
        let cancelled = makeItem(status: .cancelled)
        #expect(RecurringItemFormatter.subtitle(for: cancelled) == String(localized: "Отменена"))

        let paused = makeItem(status: .paused)
        #expect(RecurringItemFormatter.subtitle(for: paused) == String(localized: "На паузе"))

        let archived = makeItem(status: .archived)
        #expect(RecurringItemFormatter.subtitle(for: archived) == String(localized: "В архиве"))

        let active = makeItem(status: .active)
        let activeSubtitle = RecurringItemFormatter.subtitle(for: active)
        #expect(!activeSubtitle.isEmpty)
    }

    // MARK: - trialSubtitle

    @Test("trialSubtitle handles nil and edge cases")
    func trialSubtitleEdgeCases() {
        let noTrial = makeItem(status: .active)
        #expect(RecurringItemFormatter.trialSubtitle(for: noTrial) == String(localized: "Пробный период"))

        let endingToday = makeItem(
            status: .trial,
            trialEndDate: Date.now.addingTimeInterval(12 * 60 * 60)
        )
        let todaySubtitle = RecurringItemFormatter.trialSubtitle(for: endingToday)
        #expect(todaySubtitle == String(localized: "Пробный период заканчивается сегодня"))

        let manyDays = makeItem(
            status: .trial,
            trialEndDate: Date.now.addingTimeInterval(30 * 24 * 60 * 60 + 12 * 60 * 60)
        )
        let manySubtitle = RecurringItemFormatter.trialSubtitle(for: manyDays)
        #expect(manySubtitle == String(localized: "Осталось \(30) дн."))
    }

    @Test("trialSubtitle uses one-day label with one full day remaining")
    func trialSubtitleOneDay() {
        let item = makeItem(
            status: .trial,
            trialEndDate: Date.now.addingTimeInterval(36 * 60 * 60)
        )
        let subtitle = RecurringItemFormatter.trialSubtitle(for: item)
        #expect(subtitle == String(localized: "Остался 1 день"))
    }

    // MARK: - trialSeverity

    @Test("trialSeverity returns correct severity levels")
    func trialSeverityLevels() {
        let noTrial = makeItem()
        #expect(RecurringItemFormatter.trialSeverity(for: noTrial) == .info)

        let critical = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        )
        #expect(RecurringItemFormatter.trialSeverity(for: critical) == .critical)

        let warning = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)
        )
        let warningSeverity = RecurringItemFormatter.trialSeverity(for: warning)
        #expect(warningSeverity == .warning || warningSeverity == .critical)

        let info = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)
        )
        #expect(RecurringItemFormatter.trialSeverity(for: info) == .info)
    }

    // MARK: - trialCountLabel

    @Test("trialCountLabel is non-empty and contains digit for all meaningful counts")
    func trialCountLabelNonEmpty() {
        // The full string includes the count: "1 пробный", "5 пробных", "1 trial", etc.
        for count in [1, 2, 5, 11, 21, 111] {
            let label = RecurringItemFormatter.trialCountLabel(count: count)
            #expect(!label.isEmpty, "trialCountLabel is empty for count=\(count)")
            #expect(label.contains("\(count)"), "trialCountLabel missing digit for count=\(count)")
        }
    }

    @Test("trialCountLabel does not contain raw format specifier (xcstrings key resolved)")
    func trialCountLabelNoRawSpecifier() {
        for count in [1, 2, 5, 11] {
            let label = RecurringItemFormatter.trialCountLabel(count: count)
            #expect(!label.contains("%lld"), "label contains raw %lld for count=\(count)")
            #expect(!label.contains("%@"),   "label contains raw %@ for count=\(count)")
        }
    }

    @Test("trialCountLabel count=1 and count=2 differ (one vs few/many)")
    func trialCountLabelOneVsMany() {
        // RU: count=1 → "1 пробный" (one), count=2 → "2 пробных" (few).
        // EN: count=1 → "1 trial"   (one), count=2 → "2 trials"  (other).
        // Either way, the word part must differ — proving CLDR plural selection fires.
        let one = RecurringItemFormatter.trialCountLabel(count: 1)
        let two = RecurringItemFormatter.trialCountLabel(count: 2)
        #expect(one != two, "count=1 and count=2 produce the same string — plural selection may be broken")
    }

    @Test("trialCountLabel count=2 and count=5 match (few and many use same adjective form)")
    func trialCountLabelFewEqualsMany() {
        // RU: both 2 (few) and 5 (many) → "пробных".
        // EN: both 2 (other) and 5 (other) → "trials".
        // Verify no accidental split between the two non-singular categories.
        let two  = RecurringItemFormatter.trialCountLabel(count: 2)
        let five = RecurringItemFormatter.trialCountLabel(count: 5)
        // Strip leading digit+space to compare word parts only (locale-agnostic)
        let wordTwo  = two.drop(while:  { $0.isNumber }).drop(while: { $0 == " " })
        let wordFive = five.drop(while: { $0.isNumber }).drop(while: { $0 == " " })
        #expect(wordTwo == wordFive, "count=2 and count=5 word parts differ — unexpected few/many split")
    }

    @Test("trialCountLabel teen case (11) uses same form as 5 (many in Russian)")
    func trialCountLabelTeenCase() {
        // Russian: 11 → "many" (пробных), same as 5. Teens are exempt from "few" rule.
        let eleven = RecurringItemFormatter.trialCountLabel(count: 11)
        let five   = RecurringItemFormatter.trialCountLabel(count: 5)
        let wordEleven = eleven.drop(while: { $0.isNumber }).drop(while: { $0 == " " })
        let wordFive   = five.drop(while:   { $0.isNumber }).drop(while: { $0 == " " })
        #expect(wordEleven == wordFive, "count=11 and count=5 word parts differ — teen CLDR rule may be broken")
    }
}

// MARK: - InsightsBuilder Tests

@Suite("InsightsBuilder")
struct InsightsBuilderTests {

    private func makeItem(
        status: ItemStatus = .active,
        daysOffset: Int = 3,
        amount: Decimal = 299
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            amount: amount,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: daysOffset, to: .now)!,
            status: status
        )
    }

    @Test("Empty charges produce no insights")
    func emptyCharges() {
        let insights = InsightsBuilder.build(from: [])
        #expect(insights.isEmpty)
    }

    @Test("Overdue items produce critical insight")
    func overdueInsight() {
        let items = [
            makeItem(daysOffset: -2),
            makeItem(daysOffset: -5),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .critical && $0.title.contains("2") })
    }

    @Test("Failed items produce critical insight")
    func failedInsight() {
        let items = [
            makeItem(status: .failed, daysOffset: 1),
            makeItem(daysOffset: 3),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .critical && $0.title.contains("1") })
    }

    @Test("Multiple charges produce info insight")
    func multipleChargesInsight() {
        let items = [
            makeItem(daysOffset: 1, amount: 100),
            makeItem(daysOffset: 3, amount: 200),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .info && $0.title.contains("2") })
    }

    @Test("Single charge with no issues produces no insights")
    func singleNormalCharge() {
        let insights = InsightsBuilder.build(from: [makeItem()])
        #expect(insights.isEmpty)
    }
}

// MARK: - Presentation Localization Tests

@Suite("Presentation Localization")
struct PresentationLocalizationTests {

    private func localizationBundle(_ languageCode: String) throws -> Bundle {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    private func containsCyrillic(_ value: String) -> Bool {
        value.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    @Test("App language and regional conventions are resolved independently")
    func localeResolutionKeepsRegionalConventions() {
        let englishForRussianRegion = PresentationLocale.resolved(
            appLanguageIdentifier: "en",
            regionalLocale: Locale(identifier: "ru_RU")
        )
        #expect(englishForRussianRegion.language.languageCode?.identifier == "en")
        #expect(englishForRussianRegion.region?.identifier == "RU")

        let russianForUSRegion = PresentationLocale.resolved(
            appLanguageIdentifier: "ru",
            regionalLocale: Locale(identifier: "en_US")
        )
        #expect(russianForUSRegion.language.languageCode?.identifier == "ru")
        #expect(russianForUSRegion.region?.identifier == "US")
    }

    @Test("Calendar labels follow app language")
    func calendarLabelsFollowAppLanguage() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))

        let english = PresentationLocale.dateFormatter(
            template: "LLLL yyyy",
            locale: Locale(identifier: "en_RU"),
            calendar: calendar
        ).string(from: date)
        let russian = PresentationLocale.dateFormatter(
            template: "LLLL yyyy",
            locale: Locale(identifier: "ru_RU"),
            calendar: calendar
        ).string(from: date)

        #expect(english.localizedCaseInsensitiveContains("July"))
        #expect(russian.localizedCaseInsensitiveContains("июль"))
    }

    @Test("Home presentation labels have English and Russian catalog values")
    func homeLabelsAreLocalized() throws {
        let english = Locale(identifier: "en")
        let russian = Locale(identifier: "ru")
        let englishBundle = try localizationBundle("en")
        let russianBundle = try localizationBundle("ru")

        #expect(String(localized: "Пик расходов", bundle: englishBundle, locale: english) == "Peak Pressure")
        #expect(String(localized: "Свободный период", bundle: englishBundle, locale: english) == "Quiet Window")
        #expect(String(localized: "прогноз", bundle: englishBundle, locale: english) == "forecast")

        #expect(String(localized: "Пик расходов", bundle: russianBundle, locale: russian) == "Пик расходов")
        #expect(String(localized: "Свободный период", bundle: russianBundle, locale: russian) == "Свободный период")
        #expect(String(localized: "прогноз", bundle: russianBundle, locale: russian) == "прогноз")
    }

    @Test("Subscription and payment counts use localized plural rules")
    func localizedCountPlurals() throws {
        let english = Locale(identifier: "en")
        let russian = Locale(identifier: "ru")
        let englishBundle = try localizationBundle("en")
        let russianBundle = try localizationBundle("ru")

        #expect(String(localized: "\(1) подписок", bundle: englishBundle, locale: english) == "1 subscription")
        #expect(String(localized: "\(2) подписок", bundle: englishBundle, locale: english) == "2 subscriptions")
        #expect(String(localized: "\(1) платежей", bundle: englishBundle, locale: english) == "1 payment")
        #expect(String(localized: "\(5) платежей", bundle: englishBundle, locale: english) == "5 payments")

        #expect(String(localized: "\(1) подписок", bundle: russianBundle, locale: russian) == "1 подписка")
        #expect(String(localized: "\(2) подписок", bundle: russianBundle, locale: russian) == "2 подписки")
        #expect(String(localized: "\(5) подписок", bundle: russianBundle, locale: russian) == "5 подписок")
        #expect(String(localized: "\(21) платежей", bundle: russianBundle, locale: russian) == "21 платёж")
    }

    @Test("Provider tier metadata has English catalog coverage")
    func providerTierMetadataHasEnglishCoverage() async throws {
        let englishBundle = try localizationBundle("en")
        let english = Locale(identifier: "en")
        let providers = ProviderCatalog.all
        let tierMetadata = Set(
            providers.flatMap(\.plans).flatMap { tier in
                [tier.name, tier.features].compactMap { $0 }
            }
        )
        let approvedVerbatimBrands: Set<String> = ["WB Клуб"]

        #expect(approvedVerbatimBrands.isSubset(of: tierMetadata))

        for source in tierMetadata.sorted() {
            let localized = String(
                localized: String.LocalizationValue(source),
                bundle: englishBundle,
                locale: english
            )

            #expect(
                !localized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "Empty English tier localization for: \(source)"
            )

            if approvedVerbatimBrands.contains(source) {
                #expect(
                    localized == source,
                    "Approved brand must remain verbatim: \(source)"
                )
            } else if containsCyrillic(source) {
                #expect(
                    localized != source && !containsCyrillic(localized),
                    "Missing English tier localization for: \(source)"
                )
            }
        }
    }
}
