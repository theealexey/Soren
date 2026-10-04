import Testing
import Foundation
@testable import Soren

// MARK: - Next Charge Date Suggestion Tests
//
// Tests for AddSubscriptionViewModel.suggestNextChargeDate(from:cycle:today:calendar:)
//
// Contract:
//   • startDate > today  → return startDate unchanged
//   • startDate == today → advance by one cycle (today is already "the start date", first charge is next cycle)
//   • startDate < today  → advance by at least one cycle, then keep advancing while
//                          candidate < today. Today counts as a valid next-charge day.

@Suite("AddSubscriptionViewModel — suggestNextChargeDate")
@MainActor
struct NextChargeDateSuggestionTests {

    // Fixed reference dates so tests are deterministic regardless of when they run.
    // "today" = 2026-04-22, a mid-month Wednesday.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = 0     // canonical Domain billing day
        return calendar.date(from: comps)!
    }

    private let today = { () -> Date in
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 22; c.hour = 0
        return cal.date(from: c)!
    }()

    private func suggest(from start: Date, cycle: BillingCycle, today explicitToday: Date? = nil, calendar explicitCalendar: Calendar? = nil) throws -> Date {
        let zone = (explicitCalendar ?? calendar).timeZone
        let result = try AddSubscriptionViewModel.suggestNextChargeDay(
            from: BillingCivilDay.civilDate(containing: start, in: zone),
            cycle: cycle, today: BillingCivilDay.civilDate(containing: explicitToday ?? today, in: zone)
        )
        return try BillingCivilDay.canonicalDate(for: result)
    }

    // MARK: - Future Start Date (before first charge)

    @Test("Future startDate: returns startDate unchanged (monthly)")
    func futureStartDateMonthlyUnchanged() throws {
        let future = date(2026, 5, 1)    // 9 days ahead of today
        let result = try suggest(from: future, cycle: .monthly)
        #expect(result == future)
    }

    @Test("Future startDate: returns startDate unchanged (annual)")
    func futureStartDateAnnualUnchanged() throws {
        let future = date(2027, 1, 1)
        let result = try suggest(from: future, cycle: .annual)
        #expect(result == future)
    }

    @Test("startDate later today than `today`: same calendar day → treated as 'started today'")
    func startDateLaterSameDayAsToday() throws {
        // today has hour=12; startDate at hour=13 is a later moment but the SAME
        // calendar day. Day-granular comparison treats this as "started today",
        // so the contract says advance one full cycle — not "return unchanged".
        // This is the new contract enforced by the startOfDay normalization; the
        // old timestamp-granular contract would have returned startDate unchanged.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 22; comps.hour = 13
        let laterToday = calendar.date(from: comps)!
        let result = try suggest(from: laterToday, cycle: .monthly)
        // Advance one cycle from laterToday → May 22 at hour=13.
        #expect(calendar.isDate(result, inSameDayAs: date(2026, 5, 22)))
    }

    // MARK: - Start Date == Today (first charge is next cycle)

    @Test("startDate == today: monthly advances by one month")
    func startDateTodayMonthlyAdvancesOneMonth() throws {
        let result = try suggest(from: today, cycle: .monthly)
        let expected = date(2026, 5, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: weekly advances by 7 days")
    func startDateTodayWeeklyAdvances7Days() throws {
        let result = try suggest(from: today, cycle: .weekly)
        let expected = date(2026, 4, 29)
        #expect(result == expected)
    }

    @Test("startDate == today: annual advances by one year")
    func startDateTodayAnnualAdvancesOneYear() throws {
        let result = try suggest(from: today, cycle: .annual)
        let expected = date(2027, 4, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: quarterly advances by 3 months")
    func startDateTodayQuarterlyAdvances3Months() throws {
        let result = try suggest(from: today, cycle: .quarterly)
        let expected = date(2026, 7, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: semiannual advances by 6 months")
    func startDateTodaySemiannualAdvances6Months() throws {
        let result = try suggest(from: today, cycle: .semiannual)
        let expected = date(2026, 10, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: custom(30) advances by 30 days")
    func startDateTodayCustom30Advances30Days() throws {
        let result = try suggest(from: today, cycle: .custom(days: 30))
        let expected = date(2026, 5, 22)
        #expect(result == expected)
    }

    // MARK: - Past Start Date (N cycles needed)

    @Test("startDate exactly 1 cycle ago: candidate lands on today, which is valid")
    func startDate1MonthAgoMonthlyLandsOnToday() throws {
        let start = date(2026, 3, 22)    // today - 1 month
        let result = try suggest(from: start, cycle: .monthly)
        // Mar 22 + 1m = Apr 22 = today → candidate is NOT < today, stop.
        // Today is a valid next-charge day.
        #expect(result == date(2026, 4, 22))
    }

    @Test("startDate 2 months ago: monthly needs 2 advances, lands past today")
    func startDate2MonthsAgoMonthly() throws {
        let start = date(2026, 2, 22)
        let result = try suggest(from: start, cycle: .monthly)
        // Feb 22 + 1m = Mar 22 < today → advance
        // Mar 22 + 1m = Apr 22 = today → stop
        #expect(result == date(2026, 4, 22))
    }

    @Test("startDate ~13 months ago: annual lands on today")
    func startDate1YearAgoAnnual() throws {
        let start = date(2025, 4, 22)
        let result = try suggest(from: start, cycle: .annual)
        // Apr 22 2025 + 1yr = Apr 22 2026 = today → stop
        #expect(result == date(2026, 4, 22))
    }

    @Test("startDate 6 months ago: semiannual lands on today")
    func startDate6MonthsAgoSemiannual() throws {
        let start = date(2025, 10, 22)
        let result = try suggest(from: start, cycle: .semiannual)
        // Oct 22 2025 + 6m = Apr 22 2026 = today → stop
        #expect(result == date(2026, 4, 22))
    }

    @Test("startDate 3 months ago: monthly advances past today (stale start)")
    func startDate3MonthsAgoMonthly() throws {
        let start = date(2026, 1, 22)
        let result = try suggest(from: start, cycle: .monthly)
        // Jan 22 → Feb 22 → Mar 22 → Apr 22 = today → stop
        #expect(result == date(2026, 4, 22))
    }

    // MARK: - Calendar edge cases

    @Test("January 31 + 1 month → February end-of-month (calendar-aware)")
    func jan31MonthlyEndOfMonth() throws {
        let jan31 = date(2026, 1, 31)
        // Jan 31 + 1m = Feb 28 < today → advance
        // Feb 28 + 1m = Mar 28 < today → advance
        // Mar 28 + 1m = Apr 28 ≥ today → stop
        let result = try suggest(from: jan31, cycle: .monthly)
        #expect(result == date(2026, 4, 28))
    }

    @Test("Result is always >= today (never in the past)")
    func resultIsNotInThePast() throws {
        let starts: [Date] = [
            date(2020, 1, 1),
            date(2025, 4, 22),
            date(2026, 4, 21),
            date(2026, 4, 22),
        ]
        for start in starts {
            let result = try suggest(from: start, cycle: .monthly)
            #expect(result >= today, "result \(result) must be >= today for start \(start)")
        }
    }

    // MARK: - Time-of-day regression (on-device bug)
    //
    // The device reproduction that motivated the day-granular fix:
    //   • today = Apr 24 at 15:00 (any time in the afternoon)
    //   • startDate = Mar 24 at 00:00 (DatePicker writes dates at midnight)
    //   • monthly cycle
    //
    // Naïve `candidate < today` compared Apr 24 00:00 < Apr 24 15:00 → true,
    // advancing to May 24. Correct behavior is Apr 24, because both sides
    // refer to the same calendar day.

    private func dateAt(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour
        return calendar.date(from: comps)!
    }

    @Test("today at 15:00, startDate at midnight one cycle ago → lands on today")
    func todayAfternoonStartMidnightOneCycleAgo() throws {
        let todayAfternoon = dateAt(2026, 4, 22, hour: 15)
        let startMidnight  = dateAt(2026, 3, 22, hour: 0)
        let result = try suggest(
            from: startMidnight, cycle: .monthly, today: todayAfternoon, calendar: calendar
        )
        // Expect Apr 22 (any time-of-day) — NOT May 22.
        #expect(calendar.isDate(result, inSameDayAs: dateAt(2026, 4, 22, hour: 0)))
    }

    @Test("today at 23:59, startDate at 06:00 same day-of-cycle two cycles ago → today")
    func todayLateEveningStartMorningTwoCyclesAgo() throws {
        let todayLate = dateAt(2026, 4, 22, hour: 23)
        let startEarly = dateAt(2026, 2, 22, hour: 6)
        let result = try suggest(
            from: startEarly, cycle: .monthly, today: todayLate, calendar: calendar
        )
        #expect(calendar.isDate(result, inSameDayAs: dateAt(2026, 4, 22, hour: 0)))
    }

    @Test("today at 00:00, startDate at 23:59 same day → future by time, same day → startDate unchanged")
    func startDateLaterSameDay() throws {
        // DatePicker behavior edge: startDate picked at end-of-day, today is start-of-day.
        // Calendar-day comparison says startDay == todayDay → proceed, advance one cycle.
        // This is the "started today" branch.
        let todayMidnight = dateAt(2026, 4, 22, hour: 0)
        let startLate = dateAt(2026, 4, 22, hour: 23)
        let result = try suggest(
            from: startLate, cycle: .monthly, today: todayMidnight, calendar: calendar
        )
        // Advance one cycle: May 22 (time-of-day preserved by nextDate, but day is what matters).
        #expect(calendar.isDate(result, inSameDayAs: dateAt(2026, 5, 22, hour: 0)))
    }

    @Test("today at 15:00, startDate tomorrow at midnight → unchanged (future)")
    func tomorrowAtMidnightReturnsUnchanged() throws {
        let todayAfternoon = dateAt(2026, 4, 22, hour: 15)
        let tomorrowMidnight = dateAt(2026, 4, 23, hour: 0)
        let result = try suggest(
            from: tomorrowMidnight, cycle: .monthly, today: todayAfternoon, calendar: calendar
        )
        #expect(result == tomorrowMidnight)
    }
}
