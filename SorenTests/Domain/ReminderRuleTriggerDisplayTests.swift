import Testing
@testable import Soren

// MARK: - ReminderRule.Trigger Display Tests

/// Verifies that ReminderRule.Trigger.displayName produces correct localized output.
/// The plural-correctness tests assume the Russian locale (matching the project's
/// primary language and the simulator locale used in CI).
@Suite("ReminderRule.Trigger — displayName")
struct ReminderRuleTriggerDisplayTests {

    // MARK: - Non-plural cases (smoke)

    @Test func onChargeDayIsNonEmpty() {
        #expect(!ReminderRule.Trigger.onChargeDay.displayName.isEmpty)
    }

    @Test func onTrialEndIsNonEmpty() {
        #expect(!ReminderRule.Trigger.onTrialEnd.displayName.isEmpty)
    }

    @Test func onAnnualRenewalIsNonEmpty() {
        #expect(!ReminderRule.Trigger.onAnnualRenewal.displayName.isEmpty)
    }

    @Test func onPaymentFailureIsNonEmpty() {
        #expect(!ReminderRule.Trigger.onPaymentFailure.displayName.isEmpty)
    }

    // MARK: - daysBefore plural forms (Russian CLDR: one / few / many)

    /// one rule: n mod 10 = 1 AND n mod 100 ≠ 11  →  "день"
    @Test func daysBefore1UsesDen() {
        let name = ReminderRule.Trigger.daysBefore(1).displayName
        #expect(name.contains("день"), "Expected 'день' for 1 day, got: \(name)")
    }

    @Test func daysBefore21UsesDen() {
        let name = ReminderRule.Trigger.daysBefore(21).displayName
        #expect(name.contains("день"), "Expected 'день' for 21 days, got: \(name)")
    }

    /// few rule: n mod 10 in 2..4 AND n mod 100 not in 12..14  →  "дня"
    @Test func daysBefore3UsesDnya() {
        let name = ReminderRule.Trigger.daysBefore(3).displayName
        #expect(name.contains("дня"), "Expected 'дня' for 3 days, got: \(name)")
    }

    @Test func daysBefore4UsesDnya() {
        let name = ReminderRule.Trigger.daysBefore(4).displayName
        #expect(name.contains("дня"), "Expected 'дня' for 4 days, got: \(name)")
    }

    /// many rule: n mod 10 in 5..9 or n mod 100 in 11..14  →  "дней"
    @Test func daysBefore7UsesDney() {
        let name = ReminderRule.Trigger.daysBefore(7).displayName
        #expect(name.contains("дней"), "Expected 'дней' for 7 days, got: \(name)")
    }

    @Test func daysBefore14UsesDney() {
        let name = ReminderRule.Trigger.daysBefore(14).displayName
        #expect(name.contains("дней"), "Expected 'дней' for 14 days (teens), got: \(name)")
    }

    // MARK: - daysBeforeTrialEnd plural forms

    @Test func daysBeforeTrialEnd1UsesDen() {
        let name = ReminderRule.Trigger.daysBeforeTrialEnd(1).displayName
        #expect(name.contains("день"), "Expected 'день' for 1 day before trial end, got: \(name)")
    }

    @Test func daysBeforeTrialEnd3UsesDnya() {
        let name = ReminderRule.Trigger.daysBeforeTrialEnd(3).displayName
        #expect(name.contains("дня"), "Expected 'дня' for 3 days before trial end, got: \(name)")
    }

    @Test func daysBeforeTrialEnd7UsesDney() {
        let name = ReminderRule.Trigger.daysBeforeTrialEnd(7).displayName
        #expect(name.contains("дней"), "Expected 'дней' for 7 days before trial end, got: \(name)")
    }

    // MARK: - Includes the count in the output

    @Test func daysBefore7ContainsCount() {
        let name = ReminderRule.Trigger.daysBefore(7).displayName
        #expect(name.contains("7"), "Expected count '7' to appear in output, got: \(name)")
    }

    @Test func daysBeforeTrialEnd3ContainsCount() {
        let name = ReminderRule.Trigger.daysBeforeTrialEnd(3).displayName
        #expect(name.contains("3"), "Expected count '3' to appear in output, got: \(name)")
    }
}
