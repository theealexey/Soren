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
//   • startDate < today  → advance by N cycles until candidate > today

@Suite("AddSubscriptionViewModel — suggestNextChargeDate")
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
        comps.hour = 12    // noon — avoids DST edge cases
        return calendar.date(from: comps)!
    }

    private let today = { () -> Date in
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var c = DateComponents(); c.year = 2026; c.month = 4; c.day = 22; c.hour = 12
        return cal.date(from: c)!
    }()

    private func suggest(from start: Date, cycle: BillingCycle) -> Date {
        AddSubscriptionViewModel.suggestNextChargeDate(
            from: start, cycle: cycle, today: today, calendar: calendar
        )
    }

    // MARK: - Future Start Date (before first charge)

    @Test("Future startDate: returns startDate unchanged (monthly)")
    func futureStartDateMonthlyUnchanged() {
        let future = date(2026, 5, 1)    // 9 days ahead of today
        let result = suggest(from: future, cycle: .monthly)
        #expect(result == future)
    }

    @Test("Future startDate: returns startDate unchanged (annual)")
    func futureStartDateAnnualUnchanged() {
        let future = date(2027, 1, 1)
        let result = suggest(from: future, cycle: .annual)
        #expect(result == future)
    }

    @Test("startDate exactly one second in the future: returns startDate unchanged")
    func startDateOneSecondAhead() {
        // today has hour=12; use hour=13 to be clearly > today
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 22; comps.hour = 13
        let slightlyFuture = calendar.date(from: comps)!
        let result = suggest(from: slightlyFuture, cycle: .monthly)
        #expect(result == slightlyFuture)
    }

    // MARK: - Start Date == Today (first charge is next cycle)

    @Test("startDate == today: monthly advances by one month")
    func startDateTodayMonthlyAdvancesOneMonth() {
        let result = suggest(from: today, cycle: .monthly)
        let expected = date(2026, 5, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: weekly advances by 7 days")
    func startDateTodayWeeklyAdvances7Days() {
        let result = suggest(from: today, cycle: .weekly)
        let expected = date(2026, 4, 29)
        #expect(result == expected)
    }

    @Test("startDate == today: annual advances by one year")
    func startDateTodayAnnualAdvancesOneYear() {
        let result = suggest(from: today, cycle: .annual)
        let expected = date(2027, 4, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: quarterly advances by 3 months")
    func startDateTodayQuarterlyAdvances3Months() {
        let result = suggest(from: today, cycle: .quarterly)
        let expected = date(2026, 7, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: semiannual advances by 6 months")
    func startDateTodaySemiannualAdvances6Months() {
        let result = suggest(from: today, cycle: .semiannual)
        let expected = date(2026, 10, 22)
        #expect(result == expected)
    }

    @Test("startDate == today: custom(30) advances by 30 days")
    func startDateTodayCustom30Advances30Days() {
        let result = suggest(from: today, cycle: .custom(days: 30))
        let expected = date(2026, 5, 22)
        #expect(result == expected)
    }

    // MARK: - Past Start Date (N cycles needed)

    @Test("startDate 1 month ago: monthly needs 1 advance")
    func startDate1MonthAgoMonthly() {
        let start = date(2026, 3, 22)    // today - 31 days
        let result = suggest(from: start, cycle: .monthly)
        let expected = date(2026, 4, 22) // start + 1m = today, so advance again → May 22
        // start + 1 month = Apr 22 = today (not strictly after), so advance again
        #expect(result == date(2026, 5, 22))
    }

    @Test("startDate 2 months ago: monthly needs 2 advances")
    func startDate2MonthsAgoMonthly() {
        let start = date(2026, 2, 22)
        let result = suggest(from: start, cycle: .monthly)
        // Feb 22 + 1m = Mar 22 ≤ today → advance
        // Mar 22 + 1m = Apr 22 ≤ today → advance
        // Apr 22 + 1m = May 22 > today ✓
        #expect(result == date(2026, 5, 22))
    }

    @Test("startDate 13 months ago: annual needs 1 advance from 1 year ago")
    func startDate13MonthsAgoAnnual() {
        let start = date(2025, 3, 22)
        let result = suggest(from: start, cycle: .annual)
        // Mar 22 2025 + 1yr = Mar 22 2026 ≤ today → advance
        // Mar 22 2026 + 1yr = Mar 22 2027 > today ✓
        #expect(result == date(2027, 3, 22))
    }

    @Test("startDate 6 months ago: semiannual needs 1 advance")
    func startDate6MonthsAgoSemiannual() {
        let start = date(2025, 10, 22)
        let result = suggest(from: start, cycle: .semiannual)
        // Oct 22 2025 + 6m = Apr 22 2026 = today ≤ today → advance
        // Apr 22 2026 + 6m = Oct 22 2026 > today ✓
        #expect(result == date(2026, 10, 22))
    }

    // MARK: - Calendar edge cases

    @Test("January 31 + 1 month → February end-of-month (calendar-aware)")
    func jan31MonthlyEndOfMonth() {
        let jan31 = date(2026, 1, 31)
        // today = Apr 22 so Jan 31 + 1m = Feb 28 ≤ today, Feb 28 + 1m = Mar 28 ≤ today,
        // Mar 28 + 1m = Apr 28 > today ✓
        let result = suggest(from: jan31, cycle: .monthly)
        #expect(result == date(2026, 4, 28))
    }

    @Test("Result is always strictly after today")
    func resultIsStrictlyAfterToday() {
        let starts: [Date] = [
            date(2020, 1, 1),
            date(2025, 4, 22),
            date(2026, 4, 21),
            date(2026, 4, 22),
        ]
        for start in starts {
            let result = suggest(from: start, cycle: .monthly)
            #expect(result > today, "result \(result) must be > today for start \(start)")
        }
    }
}
