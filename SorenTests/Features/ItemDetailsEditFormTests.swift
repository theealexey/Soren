import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - ItemDetailsViewModel Edit Form Tests
//
// Covers the device-reproducible bug:
//   Open Edit form → startDate == Apr 24 / nextCharge == May 24.
//   Change startDate to Mar 24 → nextCharge must become Apr 24 (today).
//
// And the manual-override contract:
//   Once the user picks a next-charge date in this session, later startDate
//   changes must not overwrite it.

@Suite("ItemDetailsViewModel — edit form nextChargeDate")
@MainActor
struct ItemDetailsEditFormTests {

    // MARK: - Helpers

    private func makeRepositories() throws -> RepositoryContainer {
        let container = try SorenModelContainer.inMemory()
        return RepositoryContainer(context: container.mainContext)
    }

    private func makeItem(
        startDate: Date,
        nextChargeDate: Date,
        cycle: BillingCycle = .monthly
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            providerName: "Test",
            itemType: .subscription,
            category: .other,
            amount: 299,
            currencyCode: "RUB",
            billingCycle: cycle,
            startDate: startDate,
            nextChargeDate: nextChargeDate,
            autoRenew: true,
            chargeReminder: .threeDaysBefore,
            status: .active,
            usageStatus: .unknown
        )
    }

    /// Today's calendar day at 00:00 (stable across the test run).
    private var todayStartOfDay: Date {
        Date(timeIntervalSince1970: 1_786_752_000) // 2026-08-15 UTC
    }

    // MARK: - Recompute on startDate change

    @Test("Changing startDate applies the calendar-aware automatic monthly suggestion")
    func changingStartDateRecomputesNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let oneMonthFromToday = try #require(
            cal.date(byAdding: .month, value: 1, to: today)
        )
        let stored = makeItem(startDate: today, nextChargeDate: oneMonthFromToday)

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // Seed preserved: next-charge stayed at the stored value.
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthFromToday)))

        // Use the first of the month so calendar clamping at days 29–31 cannot
        // change the intended billing occurrence. The VM owns the current-day
        // lookup; its pure date arithmetic is covered with fixed UTC dates by
        // NextChargeDateSuggestionTests.
        let currentMonth = try #require(cal.dateInterval(of: .month, for: today))
        let firstOfCurrentMonth = currentMonth.start
        let previousMonthFirst = try #require(
            cal.date(byAdding: .month, value: -1, to: firstOfCurrentMonth)
        )
        let expectedNextChargeDate = if cal.isDate(today, inSameDayAs: firstOfCurrentMonth) {
            firstOfCurrentMonth
        } else {
            try #require(
                cal.date(byAdding: .month, value: 1, to: firstOfCurrentMonth)
            )
        }

        vm.editStartDate = try BillingCivilDay.civilDate(fromCanonicalDate: previousMonthFirst)

        // A selected relationship start date is never reused as the next charge.
        // The next charge is the first monthly occurrence on or after today.
        #expect(
            vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: expectedNextChargeDate)),
            "Expected \(expectedNextChargeDate), got \(vm.editNextChargeDate)"
        )
    }

    @Test("Changing billingCycle recomputes nextChargeDate when not manually overridden")
    func changingBillingCycleRecomputesNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let oneYearFromToday = cal.date(byAdding: .year, value: 1, to: today)!
        // Stored as annual so the seeded next-charge is far enough out that a
        // monthly recompute produces a clearly different calendar day.
        let stored = makeItem(
            startDate: today,
            nextChargeDate: oneYearFromToday,
            cycle: .annual
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneYearFromToday)))

        // User switches cycle to monthly → nextCharge should recompute.
        vm.editBillingCycle = .monthly

        // startDate == today, monthly → suggest() advances one month (today not in past).
        let oneMonthFromToday = cal.date(byAdding: .month, value: 1, to: today)!
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthFromToday)))
    }

    // MARK: - Manual override

    @Test("After manual nextChargeDate pick, startDate changes do not overwrite it")
    func manualOverrideBlocksRecompute() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // User explicitly picks a specific next-charge date far in the future.
        let userPick = cal.date(byAdding: .day, value: 45, to: today)!
        vm.setEditNextChargeDateManually(try BillingCivilDay.civilDate(fromCanonicalDate: userPick))
        #expect(vm.isEditNextChargeDateManuallySet)

        // Later, user changes startDate — must NOT overwrite the manual pick.
        let oneMonthAgo = cal.date(byAdding: .month, value: -1, to: today)!
        vm.editStartDate = try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthAgo)

        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: userPick)))
    }

    @Test("After manual nextChargeDate pick, billingCycle changes do not overwrite it")
    func manualOverrideBlocksCycleRecompute() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        let userPick = cal.date(byAdding: .day, value: 100, to: today)!
        vm.setEditNextChargeDateManually(try BillingCivilDay.civilDate(fromCanonicalDate: userPick))

        vm.editBillingCycle = .annual

        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: userPick)))
    }

    // MARK: - Seed integrity

    @Test("startEditing seeds nextChargeDate exactly to the stored value")
    func startEditingSeedsStoredNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: cal.date(byAdding: .day, value: -10, to: today)!,
            nextChargeDate: cal.date(byAdding: .day, value: 20, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // Seed must not be clobbered by the billingCycle/startDate didSets that
        // fire during assignment inside startEditing().
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: stored.nextChargeDate)))
        // Manual-override flag must be released after seed so later edits
        // engage the auto-suggest path.
        #expect(vm.isEditNextChargeDateManuallySet == false)
    }
}
