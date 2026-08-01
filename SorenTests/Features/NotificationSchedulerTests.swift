import Testing
import Foundation
@testable import Soren

@Suite("Notification request planner")
struct NotificationRequestPlannerTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return value
    }

    private var planner: NotificationRequestPlanner {
        NotificationRequestPlanner(
            calendar: calendar,
            locale: Locale(identifier: "en_US"),
            bundle: Bundle(identifier: "com.alexey.soren") ?? .main
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) throws -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.timeZone = calendar.timeZone
        return try #require(calendar.date(from: components))
    }

    private func item(
        date: Date,
        autoRenew: Bool = true,
        chargeReminder: ChargeReminderOption = .threeDaysBefore,
        trialEndDate: Date? = nil,
        trialReminder: TrialReminderOption = .never
    ) -> RecurringItem {
        RecurringItem(
            title: "Spotify",
            amount: 599,
            currencyCode: "RUB",
            billingCycle: .monthly,
            nextChargeDate: date,
            trialEndDate: trialEndDate,
            autoRenew: autoRenew,
            endDate: autoRenew ? nil : date,
            chargeReminder: chargeReminder,
            trialReminder: trialReminder
        )
    }

    private func requestCount(
        status: ItemStatus,
        autoRenew: Bool = true,
        endDate: Date? = nil
    ) throws -> Int {
        var subscription = item(date: try date(2026, 8, 12), autoRenew: autoRenew)
        subscription.status = status
        subscription.endDate = endDate
        return planner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.count
    }

    @Test("three-day charge reminder uses local 09:00")
    func chargeReminderUsesExpectedFireDate() throws {
        let now = try date(2026, 8, 1)
        let plan = planner.plan(items: [item(date: try date(2026, 8, 12))], now: now)
        let request = try #require(plan.requests.first)
        let expected = try date(2026, 8, 9, 9)
        #expect(request.fireDate == expected)
        #expect(request.trigger.hour == 9)
        #expect(request.trigger.minute == 0)
        #expect(!request.trigger.repeats)
    }

    @Test("missed automatic reminder advances to the next billing occurrence")
    func missedAutomaticReminderAdvancesCycle() throws {
        let now = try date(2026, 8, 10)
        let plan = planner.plan(items: [item(date: try date(2026, 8, 12))], now: now)
        let request = try #require(plan.requests.first)
        let occurrence = try date(2026, 9, 12)
        let fireDate = try date(2026, 9, 9, 9)
        #expect(request.occurrenceDate == occurrence)
        #expect(request.fireDate == fireDate)
    }

    @Test("missed finite and trial reminders are skipped")
    func staleFiniteAndTrialAreSkipped() throws {
        let now = try date(2026, 8, 10)
        let finite = item(date: try date(2026, 8, 12), autoRenew: false)
        let trial = item(
            date: try date(2026, 9, 12),
            chargeReminder: .never,
            trialEndDate: try date(2026, 8, 12),
            trialReminder: .threeDaysBefore
        )
        let plan = planner.plan(items: [finite, trial], now: now)
        #expect(plan.requests.isEmpty)
    }

    @Test("today before 09:00 schedules today and after 09:00 advances automatic cycle")
    func todayBoundaryIsNotShiftedToTomorrow() throws {
        let occurrence = try date(2026, 8, 12)
        let before = planner.plan(items: [item(date: occurrence, chargeReminder: .sameDay)], now: try date(2026, 8, 12, 8))
        let after = planner.plan(items: [item(date: occurrence, chargeReminder: .sameDay)], now: try date(2026, 8, 12, 10))
        let expectedFireDate = try date(2026, 8, 12, 9)
        let expectedOccurrence = try date(2026, 9, 12)
        #expect(before.requests.first?.fireDate == expectedFireDate)
        #expect(after.requests.first?.occurrenceDate == expectedOccurrence)
    }

    @Test("identities include kind, local occurrence and offset")
    func identitiesAreVersionedAndDistinct() throws {
        let charge = item(date: try date(2026, 8, 12), trialEndDate: try date(2026, 8, 15), trialReminder: .threeDaysBefore)
        let first = planner.plan(items: [charge], now: try date(2026, 8, 1))
        #expect(first.requests.count == 2)
        let chargeID = try #require(first.requests.first(where: { $0.kind == .charge })?.id)
        let trialID = try #require(first.requests.first(where: { $0.kind == .trial })?.id)
        #expect(chargeID.hasPrefix("soren.v2.charge."))
        #expect(trialID.hasPrefix("soren.v2.trial."))
        #expect(chargeID != trialID)

        var changed = charge
        changed.chargeReminder = .oneDayBefore
        let second = planner.plan(items: [changed], now: try date(2026, 8, 1))
        #expect(second.requests.first(where: { $0.kind == .charge })?.id != chargeID)
    }

    @Test("month-end recurrence remains calendar-aware")
    func monthEndUsesBillingCycleArithmetic() throws {
        let now = try date(2026, 2, 1)
        let plan = planner.plan(items: [item(date: try date(2026, 1, 31))], now: now)
        let expected = try date(2026, 2, 28)
        #expect(plan.requests.first?.occurrenceDate == expected)
    }

    @Test("absolute copy is localized and does not depend on today or tomorrow")
    func copyUsesAbsoluteOccurrenceDate() throws {
        let plan = planner.plan(items: [item(date: try date(2026, 8, 12))], now: try date(2026, 8, 1))
        let request = try #require(plan.requests.first)
        #expect(request.title.contains("Ожидаемое списание"))
        #expect(request.title.contains("Spotify"))
        #expect(request.body.contains("2026"))
        #expect(!request.title.localizedCaseInsensitiveContains("today"))
        #expect(!request.title.localizedCaseInsensitiveContains("tomorrow"))
    }

    @Test("one-day charge reminder preserves the selected offset")
    func oneDayReminderUsesSelectedOffset() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 8, 12), chargeReminder: .oneDayBefore)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 11, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 1)
    }

    @Test("same-day charge reminder preserves zero offset")
    func sameDayReminderUsesZeroOffset() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 8, 12), chargeReminder: .sameDay)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 12, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 0)
    }

    @Test("seven-day charge reminder preserves the selected offset")
    func sevenDayReminderUsesSelectedOffset() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 8, 12), chargeReminder: .sevenDaysBefore)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 5, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 7)
    }

    @Test("three-day reminder crosses a month boundary in the injected calendar")
    func reminderCrossesMonthBoundary() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 9, 1))],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 29, 9)
        #expect(plan.requests.first?.fireDate == expected)
    }

    @Test("three-day reminder crosses a year boundary in the injected calendar")
    func reminderCrossesYearBoundary() throws {
        let plan = planner.plan(
            items: [item(date: try date(2027, 1, 2))],
            now: try date(2026, 12, 1)
        )
        let expected = try date(2026, 12, 30, 9)
        #expect(plan.requests.first?.fireDate == expected)
    }

    @Test("never charge option creates no desired request")
    func neverChargeOptionCreatesNoRequest() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 8, 12), chargeReminder: .never)],
            now: try date(2026, 8, 1)
        )
        #expect(plan.requests.isEmpty)
    }

    @Test("finite charge after 09:00 is skipped instead of moved to tomorrow")
    func finiteTodayAfterDeliveryTimeIsSkipped() throws {
        let plan = planner.plan(
            items: [item(date: try date(2026, 8, 12), autoRenew: false, chargeReminder: .sameDay)],
            now: try date(2026, 8, 12, 10)
        )
        #expect(plan.requests.isEmpty)
    }

    @Test("trial after 09:00 is skipped instead of moved to tomorrow")
    func trialTodayAfterDeliveryTimeIsSkipped() throws {
        let trial = item(
            date: try date(2026, 9, 12),
            chargeReminder: .never,
            trialEndDate: try date(2026, 8, 12),
            trialReminder: .sameDay
        )
        let plan = planner.plan(items: [trial], now: try date(2026, 8, 12, 10))
        #expect(plan.requests.isEmpty)
    }

    @Test("occurrence date changes the versioned identifier")
    func occurrenceChangeChangesIdentifier() throws {
        let original = item(date: try date(2026, 8, 12))
        var changed = original
        changed.nextChargeDate = try date(2026, 8, 15)
        let now = try date(2026, 8, 1)
        let first = try #require(planner.plan(items: [original], now: now).requests.first)
        let second = try #require(planner.plan(items: [changed], now: now).requests.first)
        #expect(first.id != second.id)
    }

    @Test("identical planner input produces an identical identifier")
    func identicalInputProducesIdenticalIdentifier() throws {
        let subscription = item(date: try date(2026, 8, 12))
        let now = try date(2026, 8, 1)
        let first = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let second = try #require(planner.plan(items: [subscription], now: now).requests.first)
        #expect(first.id == second.id)
    }

    @Test("active status remains eligible")
    func activeStatusIsEligible() throws {
        let count = try requestCount(status: .active)
        #expect(count == 1)
    }

    @Test("due-soon status remains eligible")
    func dueSoonStatusIsEligible() throws {
        let count = try requestCount(status: .dueSoon)
        #expect(count == 1)
    }

    @Test("due-today status remains eligible")
    func dueTodayStatusIsEligible() throws {
        let count = try requestCount(status: .dueToday)
        #expect(count == 1)
    }

    @Test("overdue status remains eligible")
    func overdueStatusIsEligible() throws {
        let count = try requestCount(status: .overdue)
        #expect(count == 1)
    }

    @Test("trial status remains eligible")
    func trialStatusIsEligible() throws {
        let count = try requestCount(status: .trial)
        #expect(count == 1)
    }

    @Test("failed status remains eligible")
    func failedStatusIsEligible() throws {
        let count = try requestCount(status: .failed)
        #expect(count == 1)
    }

    @Test("paused status creates no request")
    func pausedStatusIsIneligible() throws {
        let count = try requestCount(status: .paused)
        #expect(count == 0)
    }

    @Test("cancelled status creates no request")
    func cancelledStatusIsIneligible() throws {
        let count = try requestCount(status: .cancelled)
        #expect(count == 0)
    }

    @Test("archived status creates no request")
    func archivedStatusIsIneligible() throws {
        let count = try requestCount(status: .archived)
        #expect(count == 0)
    }

    @Test("expired finite item creates no request")
    func expiredFiniteItemIsIneligible() throws {
        let endDate = try date(2026, 7, 31)
        let count = try requestCount(status: .active, autoRenew: false, endDate: endDate)
        #expect(count == 0)
    }

    @Test("finite item with future end date remains eligible")
    func futureFiniteItemIsEligible() throws {
        let endDate = try date(2026, 8, 20)
        let count = try requestCount(status: .active, autoRenew: false, endDate: endDate)
        #expect(count == 1)
    }

    @Test("weekly automatic renewal advances from a missed reminder")
    func weeklyRenewalAdvancesFromMissedReminder() throws {
        var subscription = item(date: try date(2026, 8, 12))
        subscription.billingCycle = .weekly
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2026, 8, 19)
        #expect(request.occurrenceDate == expected)
    }

    @Test("quarterly automatic renewal advances from a missed reminder")
    func quarterlyRenewalAdvancesFromMissedReminder() throws {
        var subscription = item(date: try date(2026, 8, 12))
        subscription.billingCycle = .quarterly
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2026, 11, 12)
        #expect(request.occurrenceDate == expected)
    }

    @Test("semiannual automatic renewal advances from a missed reminder")
    func semiannualRenewalAdvancesFromMissedReminder() throws {
        var subscription = item(date: try date(2026, 8, 12))
        subscription.billingCycle = .semiannual
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2027, 2, 12)
        #expect(request.occurrenceDate == expected)
    }

    @Test("yearly automatic renewal advances from a missed reminder")
    func yearlyRenewalAdvancesFromMissedReminder() throws {
        var subscription = item(date: try date(2026, 8, 12))
        subscription.billingCycle = .annual
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2027, 8, 12)
        #expect(request.occurrenceDate == expected)
    }
}

@Suite("ChargeReminderOption")
struct ChargeReminderOptionTests {
    @Test("all persisted options retain their alert-day contract")
    func alertDaysRoundTrip() {
        #expect(ChargeReminderOption.never.alertDays == nil)
        #expect(ChargeReminderOption.sameDay.alertDays == 0)
        #expect(ChargeReminderOption.oneDayBefore.alertDays == 1)
        #expect(ChargeReminderOption.threeDaysBefore.alertDays == 3)
        #expect(ChargeReminderOption.sevenDaysBefore.alertDays == 7)
        for option in ChargeReminderOption.allCases {
            #expect(ChargeReminderOption(rawValue: option.rawValue) == option)
        }
    }

    @Test("never has no alert offset")
    func neverOffsetIsNil() { #expect(ChargeReminderOption.never.alertDays == nil) }

    @Test("same-day has zero alert offset")
    func sameDayOffsetIsZero() { #expect(ChargeReminderOption.sameDay.alertDays == 0) }

    @Test("one-day option has one-day alert offset")
    func oneDayOffsetIsOne() { #expect(ChargeReminderOption.oneDayBefore.alertDays == 1) }

    @Test("three-day option has three-day alert offset")
    func threeDayOffsetIsThree() { #expect(ChargeReminderOption.threeDaysBefore.alertDays == 3) }

    @Test("seven-day option has seven-day alert offset")
    func sevenDayOffsetIsSeven() { #expect(ChargeReminderOption.sevenDaysBefore.alertDays == 7) }

    @Test("unknown charge reminder raw value remains unavailable")
    func unknownRawValueIsNil() { #expect(ChargeReminderOption(rawValue: "futureOption") == nil) }
}
