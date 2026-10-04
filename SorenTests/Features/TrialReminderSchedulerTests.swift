import Testing
import Foundation
import SwiftData
@testable import Soren

@Suite("TrialReminderOption")
struct TrialReminderOptionTests {
    @Test("persisted reminder offsets remain stable")
    func alertDaysRoundTrip() {
        #expect(TrialReminderOption.never.alertDays == nil)
        #expect(TrialReminderOption.sameDay.alertDays == 0)
        #expect(TrialReminderOption.oneDayBefore.alertDays == 1)
        #expect(TrialReminderOption.threeDaysBefore.alertDays == 3)
        #expect(TrialReminderOption.sevenDaysBefore.alertDays == 7)
        for option in TrialReminderOption.allCases {
            #expect(TrialReminderOption(rawValue: option.rawValue) == option)
        }
    }

    @Test("trial never has no alert offset")
    func neverOffsetIsNil() { #expect(TrialReminderOption.never.alertDays == nil) }

    @Test("trial same-day has zero alert offset")
    func sameDayOffsetIsZero() { #expect(TrialReminderOption.sameDay.alertDays == 0) }

    @Test("trial one-day option has one-day alert offset")
    func oneDayOffsetIsOne() { #expect(TrialReminderOption.oneDayBefore.alertDays == 1) }

    @Test("trial three-day option has three-day alert offset")
    func threeDayOffsetIsThree() { #expect(TrialReminderOption.threeDaysBefore.alertDays == 3) }

    @Test("trial seven-day option has seven-day alert offset")
    func sevenDayOffsetIsSeven() { #expect(TrialReminderOption.sevenDaysBefore.alertDays == 7) }

    @Test("unknown trial reminder raw value is rejected")
    func unknownRawValueIsNil() { #expect(TrialReminderOption(rawValue: "twoWeeksBefore") == nil) }

    @Test("trial reminder display names are non-empty")
    func displayNamesAreNonEmpty() {
        #expect(TrialReminderOption.allCases.allSatisfy { !$0.displayName.isEmpty })
    }

    @Test("trial reminder display names are unique")
    func displayNamesAreUnique() {
        let names = TrialReminderOption.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }
}

@Suite("Trial reminder persistence")
struct TrialReminderMapperTests {
    private func item(reminder: TrialReminderOption) -> RecurringItem {
        RecurringItem(title: "Test", amount: 299, startDate: Date(timeIntervalSinceReferenceDate: 0), nextChargeDate: .distantFuture, trialReminder: reminder)
    }

    @Test("mapper retains all trial reminder options and defaults legacy rows to never")
    func mapperContract() throws {
        for option in TrialReminderOption.allCases {
            let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: option)))
            #expect(mapped.trialReminder == option)
        }
        let legacy = try RecurringItemMapper.toSD(item(reminder: .threeDaysBefore))
        legacy.trialReminderRaw = nil
        #expect(try RecurringItemMapper.toDomain(legacy).trialReminder == .never)
    }

    @Test("legacy nil trial reminder decodes to never")
    func nilRawValueDefaultsToNever() throws {
        let legacy = try RecurringItemMapper.toSD(item(reminder: .threeDaysBefore))
        legacy.trialReminderRaw = nil
        #expect(try RecurringItemMapper.toDomain(legacy).trialReminder == .never)
    }

    @Test("unknown legacy trial reminder decodes to never")
    func unknownRawValueDefaultsToNever() throws {
        let legacy = try RecurringItemMapper.toSD(item(reminder: .sameDay))
        legacy.trialReminderRaw = "twoWeeksBefore"
        #expect(try RecurringItemMapper.toDomain(legacy).trialReminder == .never)
    }

    @Test("mapper writes the selected trial reminder raw value")
    func mapperWritesSelectedRawValue() throws {
        let stored = try RecurringItemMapper.toSD(item(reminder: .never))
        var updated = try RecurringItemMapper.toDomain(stored)
        updated.trialReminder = .sevenDaysBefore
        try RecurringItemMapper.update(stored, from: updated)
        #expect(stored.trialReminderRaw == TrialReminderOption.sevenDaysBefore.rawValue)
    }

    @Test("never survives trial reminder persistence")
    func neverRoundTrips() throws {
        let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: .never)))
        #expect(mapped.trialReminder == .never)
    }

    @Test("same-day survives trial reminder persistence")
    func sameDayRoundTrips() throws {
        let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: .sameDay)))
        #expect(mapped.trialReminder == .sameDay)
    }

    @Test("one-day survives trial reminder persistence")
    func oneDayRoundTrips() throws {
        let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: .oneDayBefore)))
        #expect(mapped.trialReminder == .oneDayBefore)
    }

    @Test("three-day survives trial reminder persistence")
    func threeDayRoundTrips() throws {
        let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: .threeDaysBefore)))
        #expect(mapped.trialReminder == .threeDaysBefore)
    }

    @Test("seven-day survives trial reminder persistence")
    func sevenDayRoundTrips() throws {
        let mapped = try RecurringItemMapper.toDomain(RecurringItemMapper.toSD(item(reminder: .sevenDaysBefore)))
        #expect(mapped.trialReminder == .sevenDaysBefore)
    }
}
