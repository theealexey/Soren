import Testing
import SwiftUI
@testable import Soren

@Suite("SorenListRow — Badge & Data Integrity")
@MainActor
struct ListRowTests {

    // MARK: - Badge labels

    @Test("Trial badge has correct title")
    func trialBadge() {
        #expect(SorenListRow.Badge.trial.title == "Trial")
    }

    @Test("Due soon badge has correct title")
    func dueSoonBadge() {
        #expect(SorenListRow.Badge.dueSoon.title == "Due soon")
    }

    @Test("Failed badge has correct title")
    func failedBadge() {
        #expect(SorenListRow.Badge.failed.title == "Failed")
    }

    @Test("Paused badge has correct title")
    func pausedBadge() {
        #expect(SorenListRow.Badge.paused.title == "Paused")
    }

    @Test("Annual badge has correct title")
    func annualBadge() {
        #expect(SorenListRow.Badge.annual.title == "Annual")
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
}
