import Foundation
import Testing
import SwiftUI
@testable import Soren

@Suite("SorenListRow — Badge & Data Integrity")
@MainActor
struct ListRowTests {

    // MARK: - Badge labels

    @Test("Trial badge has correct title")
    func trialBadge() {
        #expect(SorenListRow.Badge.trial.title == String(localized: "Пробный"))
    }

    @Test("Due soon badge has correct title")
    func dueSoonBadge() {
        #expect(SorenListRow.Badge.dueSoon.title == String(localized: "Скоро"))
    }

    @Test("Failed badge has correct title")
    func failedBadge() {
        #expect(SorenListRow.Badge.failed.title == String(localized: "Ошибка"))
    }

    @Test("Paused badge has correct title")
    func pausedBadge() {
        #expect(SorenListRow.Badge.paused.title == String(localized: "Пауза"))
    }

    @Test("Annual badge has correct title")
    func annualBadge() {
        #expect(SorenListRow.Badge.annual.title == String(localized: "Годовая"))
    }

    @Test("Badge localization resources provide Russian and English titles")
    func badgeLocalizationResources() throws {
        let englishBundle = try localizationBundle("en")
        let russianBundle = try localizationBundle("ru")
        let english = Locale(identifier: "en")
        let russian = Locale(identifier: "ru")

        #expect(String(localized: "Пробный", bundle: englishBundle, locale: english) == "Trial")
        #expect(String(localized: "Скоро", bundle: englishBundle, locale: english) == "Soon")
        #expect(String(localized: "Ошибка", bundle: englishBundle, locale: english) == "Error")
        #expect(String(localized: "Пауза", bundle: englishBundle, locale: english) == "Paused")
        #expect(String(localized: "Годовая", bundle: englishBundle, locale: english) == "Annual")

        #expect(String(localized: "Пробный", bundle: russianBundle, locale: russian) == "Пробный")
        #expect(String(localized: "Скоро", bundle: russianBundle, locale: russian) == "Скоро")
        #expect(String(localized: "Ошибка", bundle: russianBundle, locale: russian) == "Ошибка")
        #expect(String(localized: "Пауза", bundle: russianBundle, locale: russian) == "Пауза")
        #expect(String(localized: "Годовая", bundle: russianBundle, locale: russian) == "Годовая")
    }

    // MARK: - Badge colors are semantically correct

    @Test("Failed badge uses error color")
    func failedColor() {
        #expect(SorenListRow.Badge.failed.color == ColorTokens.error)
    }

    @Test("Trial badge uses warning color")
    func trialColor() {
        #expect(SorenListRow.Badge.trial.color == ColorTokens.warning)
    }

    @Test("Due soon badge uses info color")
    func dueSoonColor() {
        #expect(SorenListRow.Badge.dueSoon.color == ColorTokens.info)
    }

    // MARK: - Row creation edge cases

    @Test("Row with nil subtitle and nil badge")
    func minimalRow() {
        let row = SorenListRow(title: "Test", amount: 0, badge: nil)
        #expect(row.subtitle == nil)
        #expect(row.badge == nil)
    }

    @Test("Row default currency is RUB")
    func defaultCurrency() {
        let row = SorenListRow(title: "Test", amount: 100)
        #expect(row.currencyCode == "RUB")
    }

    @Test("Row default cycle is monthly")
    func defaultCycle() {
        let row = SorenListRow(title: "Test", amount: 100)
        #expect(row.cycle != nil)
    }

    @Test("Row with empty title")
    func emptyTitle() {
        let row = SorenListRow(title: "", amount: 100)
        #expect(row.title.isEmpty)
    }

    private func localizationBundle(_ languageCode: String) throws -> Bundle {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}
