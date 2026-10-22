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
    @Test("Derived normalized costs retain errors, original amount and edit capability, then recover")
    func normalizationFailureRecovers() throws {
        let anchor = todayStartOfDay
        let source = makeItem(startDate: anchor, nextChargeDate: anchor)
        let repositories = try makeRepositories()
        try repositories.recurringItems.save(source)
        let vm = ItemDetailsViewModel(item: source, repositories: repositories,
            exchangeRateProvider: StaticExchangeRateProvider(), now: { anchor }, timeZone: { .gmt })
        #expect(vm.normalizedMonthlyAmount == 299)
        #expect(vm.normalizedAnnualAmount == 3588)
        vm.item.billingCycle = .custom(days: -1)
        #expect(vm.normalizationError as? BillingCycle.ValidationError == .invalidCustomDays(-1))
        #expect(vm.normalizedMonthlyAmount == nil)
        #expect(vm.normalizedAnnualAmount == nil)
        #expect(vm.item.amount == source.amount)
        vm.startEditing()
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: anchor)))
        #expect(try repositories.recurringItems.fetch(id: source.id) == source)
        vm.item.billingCycle = .annual
        #expect(vm.normalizationError == nil)
        #expect(vm.normalizedAnnualAmount == 299)
        #expect(vm.normalizedMonthlyAmount == Decimal(299) / 12)
        #expect(vm.nextScheduledChargeState == .scheduled(try BillingCivilDay.civilDate(fromCanonicalDate: anchor)))
    }

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

    @Test("Details projects November while Edit preserves the October anchor")
    func projectedDisplayPreservesEditAnchor() async throws {
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        let reference = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 21))
        let source = makeItem(startDate: anchor, nextChargeDate: anchor)
        let repositories = try makeRepositories()
        try repositories.recurringItems.save(source)
        var clockReads = 0
        let vm = ItemDetailsViewModel(
            item: source, repositories: repositories, exchangeRateProvider: StaticExchangeRateProvider(),
            now: { clockReads += 1; return reference }, timeZone: { .gmt }
        )
        let expected = try CivilDate(year: 2026, month: 11, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(expected))
        #expect(vm.nextScheduledChargeError == nil)
        #expect(vm.formattedNextCharge == (try BillingDatePresentation.string(
            from: BillingCivilDay.canonicalDate(for: expected))))
        let reads = clockReads
        _ = vm.formattedNextCharge
        _ = vm.nextScheduledChargeState
        #expect(clockReads == reads)
        #expect(try repositories.recurringItems.fetch(id: source.id)?.nextChargeDate == anchor)
        vm.startEditing()
        let anchorDay = try CivilDate(year: 2026, month: 10, day: 15)
        #expect(vm.editNextChargeDate == anchorDay)
        vm.editTitle = "Renamed"
        try await vm.saveChanges()
        #expect(vm.item.nextChargeDate == anchor)
        #expect(try repositories.recurringItems.fetch(id: source.id)?.nextChargeDate == anchor)
        #expect(vm.nextScheduledChargeState == .scheduled(expected))
    }

    @Test("Unavailable projection retains error and differs from absence")
    func unavailableDisplayRetainsDiagnostic() throws {
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        var source = makeItem(startDate: anchor, nextChargeDate: anchor)
        source.status = .trial
        let vm = ItemDetailsViewModel(
            item: source, repositories: try makeRepositories(), exchangeRateProvider: StaticExchangeRateProvider(),
            now: { anchor }, timeZone: { .gmt }
        )
        #expect(vm.nextScheduledChargeState == .unavailable)
        #expect(vm.nextScheduledChargeError as? RecurringScheduleProjectionError == .monetaryScheduleUnavailable)
        #expect(vm.formattedNextCharge == String(localized: "itemDetails.nextScheduledCharge.unavailable"))
        vm.item.status = .paused
        #expect(vm.nextScheduledChargeState == .notScheduled)
        #expect(vm.nextScheduledChargeError == nil)
        #expect(vm.formattedNextCharge == String(localized: "itemDetails.nextScheduledCharge.notScheduled"))
        vm.item.status = .active
        let anchorDay = try CivilDate(year: 2026, month: 10, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(anchorDay))
    }

    @Test("Same explicit local today projects the same civil date", arguments: [
        "Europe/Stockholm", "America/Los_Angeles", "Asia/Tokyo"
    ])
    func scheduledDisplayTimezoneStability(_ zoneID: String) throws {
        let zone = try #require(TimeZone(identifier: zoneID))
        let today = try CivilDate(year: 2026, month: 10, day: 21)
        let now = try BillingDatePresentation.pickerCarrier(for: today, in: zone)
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        let vm = ItemDetailsViewModel(
            item: makeItem(startDate: anchor, nextChargeDate: anchor), repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(), now: { now }, timeZone: { zone }
        )
        #expect(vm.today == today)
        let expectedDay = try CivilDate(year: 2026, month: 11, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(expectedDay))
    }

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
