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

    private func canonical(_ instant: Date) throws -> Date {
        try BillingCivilDay.canonicalDate(for: BillingCivilDay.civilDate(containing: instant, in: calendar.timeZone))
    }

    private func item(
        date: Date,
        autoRenew: Bool = true,
        chargeReminder: ChargeReminderOption = .threeDaysBefore,
        trialEndDate: Date? = nil,
        trialReminder: TrialReminderOption = .never
    ) throws -> RecurringItem {
        RecurringItem(
            title: "Spotify",
            amount: 599,
            currencyCode: "RUB",
            billingCycle: .monthly,
            startDate: try canonical(date),
            nextChargeDate: try canonical(date),
            trialEndDate: try trialEndDate.map(canonical),
            autoRenew: autoRenew,
            endDate: autoRenew ? nil : try canonical(date),
            chargeReminder: chargeReminder,
            trialReminder: trialReminder
        )
    }

    private func requestCount(
        status: ItemStatus,
        autoRenew: Bool = true,
        endDate: Date? = nil
    ) throws -> Int {
        var subscription = try item(date: try date(2026, 8, 12), autoRenew: autoRenew)
        subscription.status = status
        subscription.endDate = try endDate.map(canonical)
        return planner.plan(items: [subscription], now: try date(2026, 8, 1)).requests.count
    }

    @Test("three-day charge reminder uses local 09:00")
    func chargeReminderUsesExpectedFireDate() throws {
        let now = try date(2026, 8, 1)
        let plan = planner.plan(items: [try item(date: try date(2026, 8, 12))], now: now)
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
        let plan = planner.plan(items: [try item(date: try date(2026, 8, 12))], now: now)
        let request = try #require(plan.requests.first)
        let occurrence = try canonical(date(2026, 9, 12))
        let fireDate = try date(2026, 9, 9, 9)
        #expect(request.occurrenceDate == occurrence)
        #expect(request.fireDate == fireDate)
    }

    @Test("missed finite and trial reminders are skipped")
    func staleFiniteAndTrialAreSkipped() throws {
        let now = try date(2026, 8, 10)
        let finite = try item(date: try date(2026, 8, 12), autoRenew: false)
        let trial = try item(
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
        let occurrence = try canonical(date(2026, 8, 12))
        let before = planner.plan(items: [try item(date: occurrence, chargeReminder: .sameDay)], now: try date(2026, 8, 12, 8))
        let after = planner.plan(items: [try item(date: occurrence, chargeReminder: .sameDay)], now: try date(2026, 8, 12, 10))
        let expectedFireDate = try date(2026, 8, 12, 9)
        let expectedOccurrence = try canonical(date(2026, 9, 12))
        #expect(before.requests.first?.fireDate == expectedFireDate)
        #expect(after.requests.first?.occurrenceDate == expectedOccurrence)
    }

    @Test("identities include kind, local occurrence and offset")
    func identitiesAreVersionedAndDistinct() throws {
        let charge = try item(date: try date(2026, 8, 12), trialEndDate: try date(2026, 8, 15), trialReminder: .threeDaysBefore)
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
        let plan = planner.plan(items: [try item(date: try date(2026, 1, 31))], now: now)
        let expected = try date(2026, 2, 28)
        #expect(plan.requests.first?.occurrenceDate == (try canonical(expected)))
    }

    @Test("absolute copy is localized and does not depend on today or tomorrow")
    func copyUsesAbsoluteOccurrenceDate() throws {
        let plan = planner.plan(items: [try item(date: try date(2026, 8, 12))], now: try date(2026, 8, 1))
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
            items: [try item(date: try date(2026, 8, 12), chargeReminder: .oneDayBefore)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 11, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 1)
    }

    @Test("same-day charge reminder preserves zero offset")
    func sameDayReminderUsesZeroOffset() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2026, 8, 12), chargeReminder: .sameDay)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 12, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 0)
    }

    @Test("seven-day charge reminder preserves the selected offset")
    func sevenDayReminderUsesSelectedOffset() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2026, 8, 12), chargeReminder: .sevenDaysBefore)],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 5, 9)
        #expect(plan.requests.first?.fireDate == expected)
        #expect(plan.requests.first?.reminderOffsetDays == 7)
    }

    @Test("three-day reminder crosses a month boundary in the injected calendar")
    func reminderCrossesMonthBoundary() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2026, 9, 1))],
            now: try date(2026, 8, 1)
        )
        let expected = try date(2026, 8, 29, 9)
        #expect(plan.requests.first?.fireDate == expected)
    }

    @Test("three-day reminder crosses a year boundary in the injected calendar")
    func reminderCrossesYearBoundary() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2027, 1, 2))],
            now: try date(2026, 12, 1)
        )
        let expected = try date(2026, 12, 30, 9)
        #expect(plan.requests.first?.fireDate == expected)
    }

    @Test("never charge option creates no desired request")
    func neverChargeOptionCreatesNoRequest() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2026, 8, 12), chargeReminder: .never)],
            now: try date(2026, 8, 1)
        )
        #expect(plan.requests.isEmpty)
    }

    @Test("finite charge after 09:00 is skipped instead of moved to tomorrow")
    func finiteTodayAfterDeliveryTimeIsSkipped() throws {
        let plan = planner.plan(
            items: [try item(date: try date(2026, 8, 12), autoRenew: false, chargeReminder: .sameDay)],
            now: try date(2026, 8, 12, 10)
        )
        #expect(plan.requests.isEmpty)
    }

    @Test("trial after 09:00 is skipped instead of moved to tomorrow")
    func trialTodayAfterDeliveryTimeIsSkipped() throws {
        let trial = try item(
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
        let original = try item(date: try date(2026, 8, 12))
        var changed = original
        changed.nextChargeDate = try canonical(date(2026, 8, 15))
        let now = try date(2026, 8, 1)
        let first = try #require(planner.plan(items: [original], now: now).requests.first)
        let second = try #require(planner.plan(items: [changed], now: now).requests.first)
        #expect(first.id != second.id)
    }

    @Test("identical planner input produces an identical identifier")
    func identicalInputProducesIdenticalIdentifier() throws {
        let subscription = try item(date: try date(2026, 8, 12))
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

    @Test("trial without proven monetary terms reports unavailable")
    func trialStatusIsEligible() throws {
        var subscription = try item(date: try date(2026, 8, 12))
        subscription.status = .trial
        let plan = planner.plan(items: [subscription], now: try date(2026, 8, 1))
        #expect(plan.requests.isEmpty)
        #expect(plan.failures == [.projectionFailed(itemID: subscription.id, reason: .monetaryScheduleUnavailable)])
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
        var subscription = try item(date: try date(2026, 8, 12))
        subscription.billingCycle = .weekly
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2026, 8, 19)
        #expect(request.occurrenceDate == (try canonical(expected)))
    }

    @Test("quarterly automatic renewal advances from a missed reminder")
    func quarterlyRenewalAdvancesFromMissedReminder() throws {
        var subscription = try item(date: try date(2026, 8, 12))
        subscription.billingCycle = .quarterly
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2026, 11, 12)
        #expect(request.occurrenceDate == (try canonical(expected)))
    }

    @Test("semiannual automatic renewal advances from a missed reminder")
    func semiannualRenewalAdvancesFromMissedReminder() throws {
        var subscription = try item(date: try date(2026, 8, 12))
        subscription.billingCycle = .semiannual
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2027, 2, 12)
        #expect(request.occurrenceDate == (try canonical(expected)))
    }

    @Test("yearly automatic renewal advances from a missed reminder")
    func yearlyRenewalAdvancesFromMissedReminder() throws {
        var subscription = try item(date: try date(2026, 8, 12))
        subscription.billingCycle = .annual
        let now = try date(2026, 8, 10)
        let request = try #require(planner.plan(items: [subscription], now: now).requests.first)
        let expected = try date(2027, 8, 12)
        #expect(request.occurrenceDate == (try canonical(expected)))
    }

    @Test("January month-end recovers in March after the February reminder passed")
    func canonicalMonthEndRecovery() throws {
        let source = try item(date: try date(2026, 1, 31))
        let february = planner.plan(items: [source], now: try date(2026, 2, 1))
        let march = planner.plan(items: [source], now: try date(2026, 3, 1))
        #expect(february.requests.first?.occurrenceDate == (try canonical(date(2026, 2, 28))))
        #expect(march.requests.first?.occurrenceDate == (try canonical(date(2026, 3, 31))))
        #expect(march.failures.isEmpty)
        #expect(source.nextChargeDate == (try canonical(date(2026, 1, 31))))
    }

    @Test("Annual leap-day anchor recovers after a non-leap year")
    func canonicalLeapRecovery() throws {
        var source = try item(date: try date(2024, 2, 29))
        source.billingCycle = .annual
        let ordinary = planner.plan(items: [source], now: try date(2027, 1, 1))
        let leap = planner.plan(items: [source], now: try date(2027, 3, 1))
        #expect(ordinary.requests.first?.occurrenceDate == (try canonical(date(2027, 2, 28))))
        #expect(leap.requests.first?.occurrenceDate == (try canonical(date(2028, 2, 29))))
    }

    @Test("Future lifecycle start excludes earlier anchor occurrences")
    func futureStartUsesCanonicalEligibility() throws {
        var source = try item(date: try date(2026, 10, 15))
        source.startDate = try canonical(date(2026, 12, 1))
        let plan = planner.plan(items: [source], now: try date(2026, 10, 1))
        #expect(plan.requests.first?.occurrenceDate == (try canonical(date(2026, 12, 15))))
    }

    @Test("Finite recurrence advances to inclusive final occurrence, then proves absence")
    func finiteCanonicalRollover() throws {
        var source = try item(date: try date(2026, 10, 15), autoRenew: false)
        source.endDate = try canonical(date(2026, 12, 15))
        let november = planner.plan(items: [source], now: try date(2026, 10, 21))
        let december = planner.plan(items: [source], now: try date(2026, 11, 21))
        let exhausted = planner.plan(items: [source], now: try date(2026, 12, 13))
        #expect(november.requests.first?.occurrenceDate == (try canonical(date(2026, 11, 15))))
        #expect(december.requests.first?.occurrenceDate == source.endDate)
        #expect(exhausted.requests.isEmpty)
        #expect(exhausted.failures.isEmpty)
    }

    @Test("At 09:00 the offset reminder advances canonically", arguments: [
        ChargeReminderOption.sameDay, .oneDayBefore, .threeDaysBefore, .sevenDaysBefore
    ])
    func exactFireBoundary(option: ChargeReminderOption) throws {
        let offset = try #require(option.alertDays)
        let source = try item(date: try date(2026, 8, 12), chargeReminder: option)
        let fire = try date(2026, 8, 12 - offset, 9)
        let before = planner.plan(items: [source], now: fire.addingTimeInterval(-1))
        let at = planner.plan(items: [source], now: fire)
        #expect(before.requests.first?.occurrenceDate == source.nextChargeDate)
        #expect(before.requests.first?.fireDate == fire)
        #expect(at.requests.first?.occurrenceDate == (try canonical(date(2026, 9, 12))))
    }

    @Test("Ambiguous trial retains its independent nonmonetary reminder")
    func ambiguousTrialPreservesBoundary() throws {
        var source = try item(date: try date(2026, 11, 20),
            trialEndDate: try date(2026, 11, 15), trialReminder: .threeDaysBefore)
        source.startDate = try canonical(date(2026, 10, 1))
        source.status = .trial
        let plan = planner.plan(items: [source], now: try date(2026, 11, 1))
        #expect(plan.requests.count == 1)
        #expect(plan.requests.first?.kind == .trial)
        #expect(plan.requests.first?.occurrenceDate == source.trialEndDate)
        #expect(plan.failures == [.projectionFailed(itemID: source.id, reason: .monetaryScheduleUnavailable)])
        source.nextChargeDate = try #require(source.trialEndDate)
        let proven = planner.plan(items: [source], now: try date(2026, 11, 1))
        #expect(proven.requests.count == 2)
        #expect(proven.failures.isEmpty)
    }

    @Test("archivedAt excludes both kinds independently of status")
    func archivedTimestampExcludesRequests() throws {
        var source = try item(date: try date(2026, 8, 12),
            trialEndDate: try date(2026, 8, 15), trialReminder: .threeDaysBefore)
        source.archivedAt = try date(2026, 8, 1)
        let plan = planner.plan(items: [source], now: try date(2026, 8, 1))
        #expect(plan.requests.isEmpty)
        #expect(plan.failures.isEmpty)
    }

    @Test("Valid cycles agree with canonical next charge", arguments: [
        BillingCycle.weekly, .monthly, .quarterly, .semiannual, .annual, .custom(days: 1), .custom(days: 7), .custom(days: 60)
    ])
    func cycleParity(cycle: BillingCycle) throws {
        var source = try item(date: try date(2020, 1, 31), chargeReminder: .sameDay)
        source.billingCycle = cycle
        let today = try CivilDate(year: 2026, month: 3, day: 1)
        let expected = try #require(try RecurringScheduleProjector().nextScheduledCharge(for: source, onOrAfter: today))
        let plan = planner.plan(items: [source], now: try date(2026, 3, 1, 8))
        let request = try #require(plan.requests.first)
        #expect(request.occurrenceDate == (try BillingCivilDay.canonicalDate(for: expected)))
        #expect(request.id == "soren.v2.charge.\(source.id.uuidString.lowercased()).\(request.occurrenceLocalDateKey).0")
        #expect(plan.failures.isEmpty)
    }

    @Test("Distant future anchor has no one-year search horizon")
    func distantFutureAnchor() throws {
        let source = try item(date: try date(2040, 11, 15))
        let plan = planner.plan(items: [source], now: try date(2026, 10, 21))
        #expect(plan.requests.first?.occurrenceDate == source.nextChargeDate)
        #expect(plan.failures.isEmpty)
    }

    @Test("Invalid custom schedule reports unavailable instead of absence")
    func invalidScheduleReportsFailure() throws {
        var source = try item(date: try date(2026, 8, 12))
        source.billingCycle = .custom(days: 0)
        let plan = planner.plan(items: [source], now: try date(2026, 8, 1))
        #expect(plan.requests.isEmpty)
        #expect(plan.failures == [.projectionFailed(itemID: source.id, reason: .monetaryScheduleUnavailable)])
    }

    @Test("Unsupported recurrence arithmetic remains a typed planning failure")
    func arithmeticFailureIsRetained() throws {
        var source = try item(date: try date(2020, 1, 1))
        source.billingCycle = .custom(days: Int.max)
        let plan = planner.plan(items: [source], now: try date(2026, 8, 1))
        #expect(plan.requests.isEmpty)
        #expect(plan.failures == [.projectionFailed(itemID: source.id, reason: .invalidCalendarArithmetic)])
    }

    @Test("Daily recurrence skips only missed offset reminders and has no anchor iteration limit")
    func dailyReminderWindow() throws {
        var source = try item(date: try date(2020, 1, 1), chargeReminder: .sevenDaysBefore)
        source.billingCycle = .custom(days: 1)
        let plan = planner.plan(items: [source], now: try date(2026, 8, 1, 10))
        #expect(plan.requests.first?.occurrenceDate == (try canonical(date(2026, 8, 9))))
        #expect(plan.requests.first?.fireDate == (try date(2026, 8, 2, 9)))
        #expect(plan.failures.isEmpty)
    }

    @Test("Local 09:00 survives DST and positive/negative zones", arguments: [
        ("America/New_York", 2026, 3, 8), ("America/New_York", 2026, 11, 1),
        ("Europe/Berlin", 2026, 3, 29), ("Pacific/Kiritimati", 2026, 3, 8)
    ])
    func localFireTimeAcrossDST(_ zoneID: String, _ year: Int, _ month: Int, _ day: Int) throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try #require(TimeZone(identifier: zoneID))
        let civil = try CivilDate(year: year, month: month, day: day)
        let occurrence = try BillingCivilDay.canonicalDate(for: civil)
        let before = try #require(local.date(from: DateComponents(year: year, month: month, day: day, hour: 8)))
        let fire = try #require(local.date(from: DateComponents(year: year, month: month, day: day, hour: 9)))
        let source = RecurringItem(title: "DST", amount: 100, currencyCode: "RUB", billingCycle: .monthly,
            startDate: occurrence, nextChargeDate: occurrence, chargeReminder: .sameDay)
        let localPlanner = NotificationRequestPlanner(calendar: local, locale: Locale(identifier: "en_US"))
        let plan = localPlanner.plan(items: [source], now: before)
        #expect(plan.requests.first?.fireDate == fire)
        #expect(plan.requests.first?.occurrenceDate == occurrence)
        #expect(plan.requests.first?.trigger.timeZoneIdentifier == zoneID)
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

extension NotificationRequestPlannerTests {
    private func decisionItem(day: Int = 12) throws -> RecurringItem {
        var value = try item(date: date(2026, 8, 20), chargeReminder: .never)
        value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: day)
        value.renewalDecisionReminderEnabled = true
        return value
    }

    @Test("Decision requires both an explicit date and enabled preference", arguments: [false, true], [false, true])
    func decisionOptIn(hasDate: Bool, enabled: Bool) throws {
        var value = try decisionItem()
        if !hasDate { value.renewalDecisionDeadline = nil }
        value.renewalDecisionReminderEnabled = enabled
        let plan = planner.plan(items: [value], now: try date(2026, 8, 1))
        #expect(plan.requests.count == (hasDate && enabled ? 1 : 0))
        #expect(plan.failures.isEmpty)
    }

    @Test("Decision is one absolute date at local 09:00 with a stable zero-offset ID")
    func decisionRequestContract() throws {
        let value = try decisionItem()
        let plan = planner.plan(items: [value], now: try date(2026, 8, 1))
        let request = try #require(plan.requests.first)
        #expect(plan.requests.count == 1 && request.kind == .renewalDecision)
        #expect(request.occurrenceDate == (try canonical(date(2026, 8, 12))))
        #expect(request.occurrenceLocalDateKey == "20260812" && request.reminderOffsetDays == 0)
        #expect(request.id == "soren.v2.renewalDecision.\(value.id.uuidString.lowercased()).20260812.0")
        #expect(request.fireDate == (try date(2026, 8, 12, 9)))
        #expect(request.trigger == NotificationTriggerPlan(year: 2026, month: 8, day: 12, hour: 9,
            minute: 0, timeZoneIdentifier: calendar.timeZone.identifier, repeats: false))
        #expect(planner.plan(items: [value], now: try date(2026, 8, 1)) == plan)
    }

    @Test("Missed decision never rolls to tomorrow or a later cycle", arguments: [-1, 0, 1])
    func decisionExactBoundary(seconds: Int) throws {
        let value = try decisionItem()
        let fire = try date(2026, 8, 12, 9)
        let plan = planner.plan(items: [value], now: fire.addingTimeInterval(Double(seconds)))
        #expect(plan.requests.count == (seconds < 0 ? 1 : 0))
        #expect(plan.failures.isEmpty)
        #expect(planner.plan(items: [value], now: try date(2026, 8, 13, 8)).requests.isEmpty)
        let originalDeadline = try CivilDate(year: 2026, month: 8, day: 12)
        #expect(value.renewalDecisionReminderEnabled && value.renewalDecisionDeadline == originalDeadline)
    }

    @Test("Decision lifecycle is independent of Free reminder eligibility", arguments: ItemStatus.allCases, [false, true])
    func decisionLifecycle(status: ItemStatus, archived: Bool) throws {
        var value = try decisionItem()
        value.status = status
        value.archivedAt = archived ? try date(2026, 8, 1) : nil
        let plan = planner.plan(items: [value], now: try date(2026, 8, 1))
        let eligible = !archived && status != .cancelled && status != .archived
        #expect(plan.requests.count == (eligible ? 1 : 0))
        #expect(plan.failures.isEmpty)
    }

    @Test("Decision honors finite civil bounds and fails closed", arguments: ["expired", "missing", "malformed", "afterEnd", "onEnd", "beforeEnd"])
    func decisionFiniteBounds(scenario: String) throws {
        var value = try decisionItem()
        value.autoRenew = false
        value.startDate = try canonical(date(2026, 8, 1)); value.nextChargeDate = value.startDate
        switch scenario {
        case "expired": value.endDate = try canonical(date(2026, 8, 11))
        case "missing": value.endDate = nil
        case "malformed": value.endDate = try canonical(date(2026, 8, 15)).addingTimeInterval(1)
        case "afterEnd":
            value.endDate = try canonical(date(2026, 8, 13))
            value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 14)
        case "onEnd": value.endDate = try canonical(date(2026, 8, 12))
        default: value.endDate = try canonical(date(2026, 8, 15))
        }
        let plan = planner.plan(items: [value], now: try date(2026, 8, 12, 8))
        #expect(plan.requests.count == (["onEnd", "beforeEnd"].contains(scenario) ? 1 : 0))
        #expect(plan.failures == (["missing", "malformed"].contains(scenario) ? [.invalidDate(itemID: value.id)] : []))
    }

    @Test("Decision does not depend on charge projection or trial monetary availability", arguments: [false, true])
    func decisionSurvivesProjectionFailure(ambiguousTrial: Bool) throws {
        var value = try decisionItem()
        value.startDate = try canonical(date(2026, 8, 1))
        value.chargeReminder = .sameDay
        if ambiguousTrial {
            value.status = .trial
            value.trialEndDate = try canonical(date(2026, 8, 12))
            value.trialReminder = .sameDay
        } else { value.billingCycle = .custom(days: 0) }
        let plan = planner.plan(items: [value], now: try date(2026, 8, 1))
        #expect(plan.requests.filter { $0.kind == .renewalDecision }.count == 1)
        #expect(plan.failures.contains(.projectionFailed(itemID: value.id, reason: .monetaryScheduleUnavailable)))
        if ambiguousTrial { #expect(plan.requests.filter { $0.kind == .trial }.count == 1) }
    }

    @Test("Decision adds a third kind without changing any Free request field")
    func decisionPreservesFreeRequests() throws {
        var value = try item(date: date(2026, 8, 12), chargeReminder: .sameDay,
            trialEndDate: date(2026, 8, 12), trialReminder: .sameDay)
        let now = try date(2026, 8, 1)
        let baseline = planner.plan(items: [value], now: now)
        value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 12)
        value.renewalDecisionReminderEnabled = true
        let extended = planner.plan(items: [value], now: now)
        #expect(baseline.requests.count == 2 && extended.requests.count == 3)
        #expect(extended.requests.filter { $0.kind != .renewalDecision } == baseline.requests)
        #expect(Set(extended.requests.map(\.id)).count == 3)
        #expect(Set(extended.requests.map(\.fireDate)).count == 1)
        #expect(extended.failures == baseline.failures)
    }

    @Test("Decision local 09:00 preserves civil components across zones and DST", arguments: [
        ("America/New_York", 2026, 3, 8), ("America/New_York", 2026, 11, 1),
        ("Europe/Berlin", 2026, 3, 29), ("Pacific/Kiritimati", 2026, 3, 8)
    ])
    func decisionZones(_ zoneID: String, _ year: Int, _ month: Int, _ day: Int) throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try #require(TimeZone(identifier: zoneID))
        var value = try decisionItem()
        value.renewalDecisionDeadline = try CivilDate(year: year, month: month, day: day)
        let now = try #require(local.date(from: DateComponents(year: year, month: month, day: day, hour: 8)))
        let plan = NotificationRequestPlanner(calendar: local, locale: Locale(identifier: "en_US")).plan(items: [value], now: now)
        let request = try #require(plan.requests.first)
        let actual = local.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        #expect(actual.year == year && actual.month == month && actual.day == day)
        #expect(actual.hour == 9 && actual.minute == 0)
        #expect(request.trigger.timeZoneIdentifier == zoneID)
    }

    @Test("Decision cannot normalize a nonexistent local civil day")
    func decisionSkippedLocalDay() throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = try #require(TimeZone(identifier: "Pacific/Apia"))
        var value = try decisionItem()
        value.renewalDecisionDeadline = try CivilDate(year: 2011, month: 12, day: 30)
        let now = try #require(local.date(from: DateComponents(year: 2011, month: 12, day: 29, hour: 12)))
        let plan = NotificationRequestPlanner(calendar: local, locale: Locale(identifier: "en_US")).plan(items: [value], now: now)
        #expect(plan.requests.isEmpty)
        #expect(plan.failures == [.invalidDate(itemID: value.id)])
    }

    @Test("Decision invalid clock fails closed")
    func decisionInvalidClock() throws {
        let value = try decisionItem()
        let plan = planner.plan(items: [value], now: Date(timeIntervalSinceReferenceDate: .nan))
        #expect(plan.requests.isEmpty)
        #expect(plan.failures == [.invalidDate(itemID: value.id)])
    }
}
