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
        Calendar.current.startOfDay(for: .now)
    }

    // MARK: - Recompute on startDate change

    @Test("Changing startDate to one cycle ago recomputes nextChargeDate to today")
    func changingStartDateRecomputesNextCharge() throws {
        let cal = Calendar.current
        let today = todayStartOfDay
        let oneMonthFromToday = cal.date(byAdding: .month, value: 1, to: today)!
        let stored = makeItem(startDate: today, nextChargeDate: oneMonthFromToday)

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider()
        )
        vm.startEditing()

        // Seed preserved: next-charge stayed at the stored value.
        #expect(cal.isDate(vm.editNextChargeDate, inSameDayAs: oneMonthFromToday))

        // User changes startDate to one month ago.
        let oneMonthAgo = cal.date(byAdding: .month, value: -1, to: today)!
        vm.editStartDate = oneMonthAgo

        // Expect next-charge recomputed to today (one cycle after one-month-ago).
        #expect(
            cal.isDate(vm.editNextChargeDate, inSameDayAs: today),
            "Expected nextChargeDate on today's calendar day, got \(vm.editNextChargeDate)"
        )
    }

    @Test("Changing billingCycle recomputes nextChargeDate when not manually overridden")
    func changingBillingCycleRecomputesNextCharge() throws {
        let cal = Calendar.current
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
            exchangeRateProvider: StaticExchangeRateProvider()
        )
        vm.startEditing()
        #expect(cal.isDate(vm.editNextChargeDate, inSameDayAs: oneYearFromToday))

        // User switches cycle to monthly → nextCharge should recompute.
        vm.editBillingCycle = .monthly

        // startDate == today, monthly → suggest() advances one month (today not in past).
        let oneMonthFromToday = cal.date(byAdding: .month, value: 1, to: today)!
        #expect(cal.isDate(vm.editNextChargeDate, inSameDayAs: oneMonthFromToday))
    }

    // MARK: - Manual override

    @Test("After manual nextChargeDate pick, startDate changes do not overwrite it")
    func manualOverrideBlocksRecompute() throws {
        let cal = Calendar.current
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider()
        )
        vm.startEditing()

        // User explicitly picks a specific next-charge date far in the future.
        let userPick = cal.date(byAdding: .day, value: 45, to: today)!
        vm.setEditNextChargeDateManually(userPick)
        #expect(vm.isEditNextChargeDateManuallySet)

        // Later, user changes startDate — must NOT overwrite the manual pick.
        let oneMonthAgo = cal.date(byAdding: .month, value: -1, to: today)!
        vm.editStartDate = oneMonthAgo

        #expect(cal.isDate(vm.editNextChargeDate, inSameDayAs: userPick))
    }

    @Test("After manual nextChargeDate pick, billingCycle changes do not overwrite it")
    func manualOverrideBlocksCycleRecompute() throws {
        let cal = Calendar.current
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider()
        )
        vm.startEditing()

        let userPick = cal.date(byAdding: .day, value: 100, to: today)!
        vm.setEditNextChargeDateManually(userPick)

        vm.editBillingCycle = .annual

        #expect(cal.isDate(vm.editNextChargeDate, inSameDayAs: userPick))
    }

    // MARK: - Seed integrity

    @Test("startEditing seeds nextChargeDate exactly to the stored value")
    func startEditingSeedsStoredNextCharge() throws {
        let cal = Calendar.current
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: cal.date(byAdding: .day, value: -10, to: today)!,
            nextChargeDate: cal.date(byAdding: .day, value: 20, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider()
        )
        vm.startEditing()

        // Seed must not be clobbered by the billingCycle/startDate didSets that
        // fire during assignment inside startEditing().
        #expect(vm.editNextChargeDate == stored.nextChargeDate)
        // Manual-override flag must be released after seed so later edits
        // engage the auto-suggest path.
        #expect(vm.isEditNextChargeDateManuallySet == false)
    }
}
