import Testing
import Foundation
@testable import Soren

// MARK: - NotificationScheduler — computeFireDate Tests

/// Tests for `NotificationScheduler.computeFireDate(chargeDate:chargeAlertDays:now:calendar:)`.
///
/// All tests use a fixed reference point of 2026-04-22 12:00 UTC so results are
/// deterministic regardless of the actual clock at run time.
/// The function is `nonisolated static` — no scheduler instantiation needed.
@Suite("NotificationScheduler — computeFireDate")
struct NotificationSchedulerFireDateTests {

    // MARK: - Fixtures

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: comps)!
    }

    // Fixed "now": 2026-04-22 12:00 UTC — midday, so today-at-09:00 is already past.
    private var now: Date { date(2026, 4, 22, hour: 12) }

    private func fire(chargeDate: Date, alertDays: Int) -> Date {
        NotificationScheduler.computeFireDate(
            chargeDate:      chargeDate,
            chargeAlertDays: alertDays,
            now:             now,
            calendar:        calendar
        )
    }

    // MARK: - Future alert day (normal path)

    @Test("3 days before a future charge: fires at 09:00 on the alert day")
    func futureChargeFiresAtAlertDay09() {
        let result = fire(chargeDate: date(2026, 5, 10), alertDays: 3)
        #expect(result == date(2026, 5, 7, hour: 9))
    }

    @Test("1-day alert: fires at 09:00 the day before the charge")
    func oneDayAlertFires09OnDayBefore() {
        let result = fire(chargeDate: date(2026, 4, 30), alertDays: 1)
        #expect(result == date(2026, 4, 29, hour: 9))
    }

    @Test("0-day alert: fires at 09:00 on the same day as the charge")
    func zeroDayAlertFiresOnChargeDay() {
        let result = fire(chargeDate: date(2026, 5, 1), alertDays: 0)
        #expect(result == date(2026, 5, 1, hour: 9))
    }

    @Test("7-day alert: fires exactly one week before the charge")
    func sevenDayAlert() {
        let result = fire(chargeDate: date(2026, 5, 15), alertDays: 7)
        #expect(result == date(2026, 5, 8, hour: 9))
    }

    // MARK: - Past alert day — today at 09:00 already passed (now = 12:00)

    @Test("Alert day was last month: falls back to tomorrow at 09:00")
    func pastAlertDayFallsBackToTomorrow() {
        // now = Apr 22 12:00; today 09:00 < now, so fallback → Apr 23 09:00
        let result = fire(chargeDate: date(2026, 4, 15), alertDays: 3)
        #expect(result == date(2026, 4, 23, hour: 9))
    }

    @Test("Alert day is today but 09:00 has passed: falls back to tomorrow at 09:00")
    func alertDayTodayPastNoonFallsBackToTomorrow() {
        // chargeDate = Apr 25, alertDays = 3 → alert day = Apr 22 (today)
        // now = Apr 22 12:00 → today 09:00 is past → tomorrow = Apr 23 09:00
        let result = fire(chargeDate: date(2026, 4, 25), alertDays: 3)
        #expect(result == date(2026, 4, 23, hour: 9))
    }

    @Test("Alert day is today but before 09:00: fires today at 09:00")
    func alertDayTodayBefore9AM() {
        // now = Apr 22 08:00 (before 09:00) → today 09:00 is in the future
        let earlyNow = date(2026, 4, 22, hour: 8)
        let result = NotificationScheduler.computeFireDate(
            chargeDate:      date(2026, 4, 25),
            chargeAlertDays: 3,
            now:             earlyNow,
            calendar:        calendar
        )
        #expect(result == date(2026, 4, 22, hour: 9))
    }

    // MARK: - Calendar edge cases

    @Test("3-day alert crossing a month boundary")
    func monthBoundaryAlert() {
        let result = fire(chargeDate: date(2026, 5, 2), alertDays: 3)
        #expect(result == date(2026, 4, 29, hour: 9))
    }

    @Test("3-day alert crossing a year boundary")
    func yearBoundaryAlert() {
        let result = fire(chargeDate: date(2027, 1, 2), alertDays: 3)
        #expect(result == date(2026, 12, 30, hour: 9))
    }

    // MARK: - Invariants

    @Test("Result is always strictly after 'now' for past charge dates")
    func resultAlwaysAfterNowForPastCharges() {
        let pastDates = [
            date(2020, 1, 1),
            date(2025, 12, 31),
            date(2026, 4, 1),
            date(2026, 4, 22),  // today
        ]
        for chargeDate in pastDates {
            let result = fire(chargeDate: chargeDate, alertDays: 3)
            #expect(result > now, "Expected future result for chargeDate \(chargeDate)")
        }
    }

    @Test("Result always fires at hour 9")
    func resultAlwaysAt9AM() {
        let dates = [
            date(2026, 4, 25),
            date(2026, 5, 10),
            date(2027, 3, 15),
        ]
        for chargeDate in dates {
            let result = fire(chargeDate: chargeDate, alertDays: 3)
            let hour = calendar.component(.hour, from: result)
            #expect(hour == 9, "Expected hour=9 for chargeDate \(chargeDate), got \(hour)")
        }
    }
}

// MARK: - NotificationScheduler — isEligible Tests

@Suite("NotificationScheduler — isEligible")
struct NotificationSchedulerEligibilityTests {

    private let scheduler = NotificationScheduler()

    private func item(
        status:    ItemStatus,
        autoRenew: Bool = true,
        endDate:   Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title:          "Test",
            amount:         9.99,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            autoRenew:      autoRenew,
            endDate:        endDate,
            status:         status
        )
    }

    @Test("Active → eligible")           func activeEligible()    { #expect( scheduler.isEligible(item(status: .active))) }
    @Test("dueSoon → eligible")          func dueSoonEligible()   { #expect( scheduler.isEligible(item(status: .dueSoon))) }
    @Test("dueToday → eligible")         func dueTodayEligible()  { #expect( scheduler.isEligible(item(status: .dueToday))) }
    @Test("overdue → eligible")          func overdueEligible()   { #expect( scheduler.isEligible(item(status: .overdue))) }
    @Test("trial → eligible")            func trialEligible()     { #expect( scheduler.isEligible(item(status: .trial))) }
    @Test("failed → eligible")           func failedEligible()    { #expect( scheduler.isEligible(item(status: .failed))) }
    @Test("paused → NOT eligible")       func pausedIneligible()  { #expect(!scheduler.isEligible(item(status: .paused))) }
    @Test("cancelled → NOT eligible")    func cancelledIneligible() { #expect(!scheduler.isEligible(item(status: .cancelled))) }
    @Test("archived → NOT eligible")     func archivedIneligible()  { #expect(!scheduler.isEligible(item(status: .archived))) }

    @Test("Expired finite subscription → NOT eligible")
    func expiredFiniteIneligible() {
        let past = Calendar.current.date(byAdding: .day, value: -10, to: .now)!
        #expect(!scheduler.isEligible(item(status: .active, autoRenew: false, endDate: past)))
    }

    @Test("Active finite subscription with future end date → eligible")
    func activeFiniteFutureEligible() {
        let future = Calendar.current.date(byAdding: .month, value: 3, to: .now)!
        #expect(scheduler.isEligible(item(status: .active, autoRenew: false, endDate: future)))
    }
}

// MARK: - Mock Notification Scheduler

/// Records scheduling calls without touching UNUserNotificationCenter.
/// Thread-safe under Swift concurrency via actor isolation of the test suite.
final class MockNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var scheduledIDs: [UUID] = []
    private(set) var cancelledIDs: [UUID] = []
    private(set) var cancelAllCallCount = 0

    func schedule(for item: RecurringItem) async { scheduledIDs.append(item.id) }
    func cancel(for itemID: UUID) async          { cancelledIDs.append(itemID) }
    func cancelAll() async                       { cancelAllCallCount += 1 }
}

// MARK: - ViewModel Wiring Tests

/// Verifies ItemDetailsViewModel drives the notification scheduler correctly
/// for each lifecycle action.
///
/// Tests are `async` so that `await Task.yield()` flushes the fire-and-forget
/// Tasks spawned inside the ViewModel before we assert on the mock.
@Suite("ItemDetailsViewModel — notification wiring")
@MainActor
struct ItemDetailsViewModelNotificationWiringTests {

    private func makeVM(
        item:      RecurringItem,
        scheduler: MockNotificationScheduler
    ) throws -> ItemDetailsViewModel {
        let container    = try SorenModelContainer.inMemory()
        let repositories = RepositoryContainer(context: container.mainContext)
        try repositories.recurringItems.save(item)
        return ItemDetailsViewModel(
            item:                  item,
            repositories:          repositories,
            exchangeRateProvider:  StaticExchangeRateProvider(),
            notificationScheduler: scheduler
        )
    }

    private func activeItem() -> RecurringItem {
        RecurringItem(
            title:          "Netflix",
            amount:         699,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        )
    }

    @Test("archive() cancels the notification")
    func archiveCancels() async throws {
        let mock = MockNotificationScheduler()
        let item = activeItem()
        let vm   = try makeVM(item: item, scheduler: mock)

        try vm.archive()
        await Task.yield()   // flush the fire-and-forget Task

        #expect(mock.cancelledIDs.contains(item.id))
    }

    @Test("delete() cancels the notification")
    func deleteCancels() async throws {
        let mock = MockNotificationScheduler()
        let item = activeItem()
        let vm   = try makeVM(item: item, scheduler: mock)

        try vm.delete()
        await Task.yield()

        #expect(mock.cancelledIDs.contains(item.id))
    }

    @Test("togglePause() on an active item cancels the notification")
    func pauseCancels() async throws {
        let mock = MockNotificationScheduler()
        let item = activeItem()
        let vm   = try makeVM(item: item, scheduler: mock)

        try vm.togglePause()   // active → paused
        await Task.yield()

        #expect(mock.cancelledIDs.contains(item.id))
    }

    @Test("togglePause() on a paused item reschedules the notification")
    func resumeSchedules() async throws {
        let mock      = MockNotificationScheduler()
        var pausedItem = activeItem()
        pausedItem.status = .paused
        let vm        = try makeVM(item: pausedItem, scheduler: mock)

        try vm.togglePause()   // paused → active
        await Task.yield()

        #expect(mock.scheduledIDs.contains(pausedItem.id))
    }
}
