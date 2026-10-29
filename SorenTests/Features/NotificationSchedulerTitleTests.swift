import Testing
import Foundation
@testable import Soren

@Suite("Notification request copy")
struct NotificationRequestCopyTests {
    private func planner(locale: String) throws -> NotificationRequestPlanner {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let languageCode = locale.hasPrefix("ru") ? "ru" : "en"
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        let bundle = try #require(Bundle(path: path))
        return NotificationRequestPlanner(
            calendar: calendar,
            locale: Locale(identifier: locale),
            bundle: bundle
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = calendar.timeZone
        return try #require(calendar.date(from: components))
    }

    private func item(trial: Bool = false) throws -> RecurringItem {
        RecurringItem(
            title: "Spotify",
            amount: 599,
            currencyCode: "RUB",
            startDate: try canonicalTestDay(1),
            nextChargeDate: try canonicalTestDay(12),
            trialEndDate: trial ? try canonicalTestDay(15) : nil,
            trialReminder: trial ? .threeDaysBefore : .never
        )
    }

    @Test("English charge copy uses an absolute occurrence date")
    func englishChargeCopy() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item()
        let now = try date(2026, 8, 1)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: now).requests.first)
        #expect(request.title.contains("Expected charge"))
        #expect(request.title.contains("Spotify"))
        #expect(request.body.contains("2026"))
    }

    @Test("Russian charge copy uses an absolute occurrence date")
    func russianChargeCopy() throws {
        let notificationPlanner = try planner(locale: "ru_RU")
        let subscription = try item()
        let now = try date(2026, 8, 1)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: now).requests.first)
        #expect(request.title.contains("Ожидаемое списание"))
        #expect(request.body.contains("2026"))
    }

    @Test("trial copy remains distinct and absolute in both supported locales")
    func trialCopy() throws {
        for locale in ["en_US", "ru_RU"] {
            let notificationPlanner = try planner(locale: locale)
            let subscription = try item(trial: true)
            let now = try date(2026, 8, 1)
            let request = try #require(notificationPlanner.plan(items: [subscription], now: now).requests.first(where: { $0.kind == .trial }))
            #expect(request.title.contains("Spotify"))
            #expect(request.body.contains("2026"))
            #expect(!request.title.localizedCaseInsensitiveContains("today"))
            #expect(!request.title.localizedCaseInsensitiveContains("tomorrow"))
        }
    }

    @Test("English charge title is not the String Catalog key")
    func englishChargeTitleIsLocalized() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(request.title != "Ожидаемое списание: %@")
    }

    @Test("Russian charge title is not the String Catalog key")
    func russianChargeTitleIsLocalized() throws {
        let notificationPlanner = try planner(locale: "ru_RU")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(request.title != "Ожидаемое списание: %@")
    }

    @Test("English trial title uses the trial-specific absolute wording")
    func englishTrialTitleIsDistinct() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item(trial: true)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first(where: { $0.kind == .trial }))
        #expect(request.title.contains("Trial ends"))
    }

    @Test("Russian trial title uses the trial-specific absolute wording")
    func russianTrialTitleIsDistinct() throws {
        let notificationPlanner = try planner(locale: "ru_RU")
        let subscription = try item(trial: true)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first(where: { $0.kind == .trial }))
        #expect(request.title.contains("Пробный период заканчивается"))
    }

    @Test("English charge body retains the occurrence date rather than fire-day wording")
    func englishChargeBodyContainsOccurrenceYear() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(request.body.contains("2026"))
    }

    @Test("Russian charge body retains the occurrence date rather than fire-day wording")
    func russianChargeBodyContainsOccurrenceYear() throws {
        let notificationPlanner = try planner(locale: "ru_RU")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(request.body.contains("2026"))
    }

    @Test("charge copy does not promise today")
    func chargeCopyDoesNotPromiseToday() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(!request.title.localizedCaseInsensitiveContains("today"))
        #expect(!request.body.localizedCaseInsensitiveContains("today"))
    }

    @Test("charge copy does not promise tomorrow")
    func chargeCopyDoesNotPromiseTomorrow() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item()
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first)
        #expect(!request.title.localizedCaseInsensitiveContains("tomorrow"))
        #expect(!request.body.localizedCaseInsensitiveContains("tomorrow"))
    }

    @Test("trial copy does not promise today")
    func trialCopyDoesNotPromiseToday() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item(trial: true)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first(where: { $0.kind == .trial }))
        #expect(!request.title.localizedCaseInsensitiveContains("today"))
        #expect(!request.body.localizedCaseInsensitiveContains("today"))
    }

    @Test("trial copy does not promise tomorrow")
    func trialCopyDoesNotPromiseTomorrow() throws {
        let notificationPlanner = try planner(locale: "en_US")
        let subscription = try item(trial: true)
        let request = try #require(notificationPlanner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.first(where: { $0.kind == .trial }))
        #expect(!request.title.localizedCaseInsensitiveContains("tomorrow"))
        #expect(!request.body.localizedCaseInsensitiveContains("tomorrow"))
    }
}

extension NotificationRequestCopyTests {
    @Test("Decision copy preserves approved absolute wording and long title", arguments: ["ru_RU", "en_US"])
    func decisionCopy(localeID: String) throws {
        let notificationPlanner = try planner(locale: localeID)
        var value = try item()
        value.chargeReminder = .never
        value.title = String(repeating: "Long subscription «Name» %@ — ", count: 20)
        value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 12)
        value.renewalDecisionReminderEnabled = true
        let request = try #require(notificationPlanner.plan(items: [value], now: try date(2026, 8, 1)).requests.first)
        let russian = localeID.hasPrefix("ru")
        #expect(request.title == (russian ? "Решение об отмене" : "Cancellation decision"))
        #expect(request.body.hasPrefix(russian ? "Ваш срок решения — " : "Your decision deadline is "))
        #expect(request.body.hasSuffix(russian ? "Решите, отменять ли «\(value.title)»." : "Decide whether to cancel “\(value.title)”."))
        #expect(request.body.contains("2026") && request.body.contains("12"))
        #expect(!request.body.contains("notification.renewalDecision") && !request.body.contains("%1$@"))
        #expect(!request.body.localizedCaseInsensitiveContains("today") && !request.body.localizedCaseInsensitiveContains("tomorrow"))
        #expect(request.body.contains(value.title))
    }
}
