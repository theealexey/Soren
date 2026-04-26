import Testing
import Foundation
@testable import Soren

// MARK: - NotificationScheduler — title formatting tests (Adversarial)

/// Validates that notification titles are built from CLDR xcstrings plural rules,
/// not from hardcoded Russian plural arithmetic.
///
/// These tests run in whatever locale the test host uses (typically English).
/// Locale-neutral assertions check:
///   - the title is non-empty (localization key resolved successfully)
///   - the title contains the subscription name (string substitution worked)
///   - the title contains the day count as digits (integer substitution worked)
///
/// If `pluralDays()` is accidentally re-introduced, the day count would be
/// embedded inside a pre-built string argument — the digit-presence checks below
/// still catch broken key lookups (empty fallback) and missing substitutions.

@Suite("NotificationScheduler — chargeTitle")
struct NotificationSchedulerChargeTitleTests {

    // MARK: - Today / tomorrow paths (unchanged)

    @Test("0 days → title is non-empty and contains name")
    func chargeTodayContainsName() {
        let title = NotificationScheduler.chargeTitle(itemTitle: "Netflix", chargeAlertDays: 0)
        #expect(!title.isEmpty)
        #expect(title.contains("Netflix"))
    }

    @Test("1 day → title is non-empty and contains name")
    func chargeTomorrowContainsName() {
        let title = NotificationScheduler.chargeTitle(itemTitle: "Spotify", chargeAlertDays: 1)
        #expect(!title.isEmpty)
        #expect(title.contains("Spotify"))
    }

    // MARK: - CLDR plural paths (default branch)

    @Test("3 days → contains name and digit '3'")
    func chargeThreeDays() {
        let title = NotificationScheduler.chargeTitle(itemTitle: "YouTube Premium", chargeAlertDays: 3)
        #expect(!title.isEmpty)
        #expect(title.contains("YouTube Premium"), "subscription name missing from title")
        #expect(title.contains("3"), "day count '3' missing from title")
    }

    @Test("5 days → contains name and digit '5'")
    func chargeFiveDays() {
        let title = NotificationScheduler.chargeTitle(itemTitle: "Apple Music", chargeAlertDays: 5)
        #expect(!title.isEmpty)
        #expect(title.contains("Apple Music"))
        #expect(title.contains("5"))
    }

    @Test("7 days → contains name and digit '7'")
    func chargeSevenDays() {
        let title = NotificationScheduler.chargeTitle(itemTitle: "iCloud+", chargeAlertDays: 7)
        #expect(!title.isEmpty)
        #expect(title.contains("iCloud+"))
        #expect(title.contains("7"))
    }

    // MARK: - Invariants

    @Test("All ChargeReminderOption alert-day values produce non-empty titles")
    func allReminderOptionsDaysNonEmpty() {
        // The alertDays values exercised by ChargeReminderOption: 0, 1, 3, 7.
        for days in [0, 1, 3, 7] {
            let title = NotificationScheduler.chargeTitle(itemTitle: "TestSub", chargeAlertDays: days)
            #expect(!title.isEmpty, "chargeTitle is empty for alertDays=\(days)")
        }
    }

    @Test("Title never equals the raw xcstrings key (key lookup succeeded)")
    func chargeTitleIsNotRawKey() {
        // If xcstrings lookup fails entirely, String(localized:) returns the key string itself.
        // The key contains "%@" and "%lld" which are never present in a resolved title.
        for days in [3, 5, 7] {
            let title = NotificationScheduler.chargeTitle(itemTitle: "App", chargeAlertDays: days)
            #expect(!title.contains("%@"), "title contains raw %@ placeholder for days=\(days)")
            #expect(!title.contains("%lld"), "title contains raw %lld placeholder for days=\(days)")
        }
    }
}

@Suite("NotificationScheduler — trialTitle")
struct NotificationSchedulerTrialTitleTests {

    // MARK: - Today / tomorrow paths (unchanged)

    @Test("0 days → title is non-empty and contains name")
    func trialTodayContainsName() {
        let title = NotificationScheduler.trialTitle(itemTitle: "Netflix", trialAlertDays: 0)
        #expect(!title.isEmpty)
        #expect(title.contains("Netflix"))
    }

    @Test("1 day → title is non-empty and contains name")
    func trialTomorrowContainsName() {
        let title = NotificationScheduler.trialTitle(itemTitle: "Spotify", trialAlertDays: 1)
        #expect(!title.isEmpty)
        #expect(title.contains("Spotify"))
    }

    // MARK: - CLDR plural paths (default branch)

    @Test("3 days → contains name and digit '3'")
    func trialThreeDays() {
        let title = NotificationScheduler.trialTitle(itemTitle: "YouTube Premium", trialAlertDays: 3)
        #expect(!title.isEmpty)
        #expect(title.contains("YouTube Premium"), "subscription name missing from title")
        #expect(title.contains("3"), "day count '3' missing from title")
    }

    @Test("5 days → contains name and digit '5'")
    func trialFiveDays() {
        let title = NotificationScheduler.trialTitle(itemTitle: "Apple TV+", trialAlertDays: 5)
        #expect(!title.isEmpty)
        #expect(title.contains("Apple TV+"))
        #expect(title.contains("5"))
    }

    @Test("7 days → contains name and digit '7'")
    func trialSevenDays() {
        let title = NotificationScheduler.trialTitle(itemTitle: "iCloud+", trialAlertDays: 7)
        #expect(!title.isEmpty)
        #expect(title.contains("iCloud+"))
        #expect(title.contains("7"))
    }

    // MARK: - Invariants

    @Test("All alertDays values produce non-empty trial titles")
    func allAlertDaysNonEmpty() {
        for days in [0, 1, 3, 7] {
            let title = NotificationScheduler.trialTitle(itemTitle: "TestSub", trialAlertDays: days)
            #expect(!title.isEmpty, "trialTitle is empty for alertDays=\(days)")
        }
    }

    @Test("Title never equals the raw xcstrings key (key lookup succeeded)")
    func trialTitleIsNotRawKey() {
        for days in [3, 5, 7] {
            let title = NotificationScheduler.trialTitle(itemTitle: "App", trialAlertDays: days)
            #expect(!title.contains("%@"), "title contains raw %@ placeholder for days=\(days)")
            #expect(!title.contains("%lld"), "title contains raw %lld placeholder for days=\(days)")
        }
    }
}
