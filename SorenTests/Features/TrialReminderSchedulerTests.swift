import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - TrialReminderOption — alertDays and displayName

@Suite("TrialReminderOption — alertDays")
struct TrialReminderOptionAlertDaysTests {

    @Test("never → alertDays is nil")
    func neverIsNil() {
        #expect(TrialReminderOption.never.alertDays == nil)
    }

    @Test("sameDay → alertDays is 0")
    func sameDayIsZero() {
        #expect(TrialReminderOption.sameDay.alertDays == 0)
    }

    @Test("oneDayBefore → alertDays is 1")
    func oneDayBeforeIsOne() {
        #expect(TrialReminderOption.oneDayBefore.alertDays == 1)
    }

    @Test("threeDaysBefore → alertDays is 3")
    func threeDaysBeforeIsThree() {
        #expect(TrialReminderOption.threeDaysBefore.alertDays == 3)
    }

    @Test("sevenDaysBefore → alertDays is 7")
    func sevenDaysBeforeIsSeven() {
        #expect(TrialReminderOption.sevenDaysBefore.alertDays == 7)
    }

    @Test("All cases round-trip through rawValue")
    func rawValueRoundTrip() {
        for option in TrialReminderOption.allCases {
            let decoded = TrialReminderOption(rawValue: option.rawValue)
            #expect(decoded == option, "rawValue round-trip failed for \(option)")
        }
    }

    @Test("Unknown rawValue returns nil (safe fallback in mapper)")
    func unknownRawValueIsNil() {
        #expect(TrialReminderOption(rawValue: "twoWeeksBefore") == nil)
    }

    @Test("All cases have non-empty displayName")
    func allDisplayNamesNonEmpty() {
        for option in TrialReminderOption.allCases {
            #expect(!option.displayName.isEmpty, "displayName is empty for \(option)")
        }
    }

    @Test("All displayNames are distinct")
    func displayNamesDistinct() {
        let names = TrialReminderOption.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }
}

// MARK: - Mapper: trialReminder round-trip

@Suite("RecurringItemMapper — trialReminder persistence")
struct TrialReminderMapperTests {

    private func baseItem(trialReminder: TrialReminderOption) -> RecurringItem {
        RecurringItem(
            title: "Test",
            amount: 299,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!,
            trialReminder: trialReminder
        )
    }

    @Test("trialReminderRaw nil decodes to .never")
    func nilRawDecodesToNever() {
        let sd = RecurringItemMapper.toSD(baseItem(trialReminder: .threeDaysBefore))
        // Simulate a legacy row that arrived without the column.
        sd.trialReminderRaw = nil
        let domain = RecurringItemMapper.toDomain(sd)
        #expect(domain.trialReminder == .never)
    }

    @Test("Unknown rawValue decodes to .never")
    func unknownRawDecodesToNever() {
        let sd = RecurringItemMapper.toSD(baseItem(trialReminder: .sameDay))
        sd.trialReminderRaw = "twoWeeksBefore"
        let domain = RecurringItemMapper.toDomain(sd)
        #expect(domain.trialReminder == .never)
    }

    @Test("All cases survive toSD → toDomain round-trip")
    func allCasesRoundTrip() {
        for option in TrialReminderOption.allCases {
            let sd = RecurringItemMapper.toSD(baseItem(trialReminder: option))
            let domain = RecurringItemMapper.toDomain(sd)
            #expect(domain.trialReminder == option, "Round-trip failed for \(option)")
        }
    }

    @Test("update(_:from:) persists trialReminderRaw")
    func updatePersistsTrialReminder() {
        let sd = RecurringItemMapper.toSD(baseItem(trialReminder: .never))
        #expect(sd.trialReminderRaw == "never")

        var updated = RecurringItemMapper.toDomain(sd)
        updated.trialReminder = .sevenDaysBefore
        RecurringItemMapper.update(sd, from: updated)

        #expect(sd.trialReminderRaw == "sevenDaysBefore")
    }
}

// MARK: - Identifier separation: charge and trial never collide

@Suite("NotificationScheduler — identifier separation")
struct TrialIdentifierSeparationTests {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: c)!
    }

    @Test("computeFireDate is reusable for trial end dates")
    func computeFireDateWorksForTrialEnd() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let trialEnd = date(2026, 5, 15)
        let now      = date(2026, 4, 22)

        let result = NotificationScheduler.computeFireDate(
            chargeDate:      trialEnd,
            chargeAlertDays: 3,
            now:             now,
            calendar:        cal
        )
        // 3 days before May 15 is May 12, at 09:00.
        var expected = DateComponents()
        expected.year = 2026; expected.month = 5; expected.day = 12
        expected.hour = 9; expected.minute = 0; expected.second = 0
        expected.timeZone = TimeZone(identifier: "UTC")
        let expectedDate = cal.date(from: expected)!
        #expect(result == expectedDate)
    }
}

// MARK: - ViewModel wiring: trialReminder seeded and persisted

@Suite("ItemDetailsViewModel — trialReminder wiring")
@MainActor
struct ItemDetailsViewModelTrialReminderTests {

    private func makeRepositories() throws -> RepositoryContainer {
        let container = try SorenModelContainer.inMemory()
        return RepositoryContainer(context: container.mainContext)
    }

    private func makeItem(trialReminder: TrialReminderOption) -> RecurringItem {
        RecurringItem(
            title: "Trial Sub",
            amount: 499,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 14, to: .now)!,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            trialReminder: trialReminder
        )
    }

    private func makeVM(item: RecurringItem) throws -> ItemDetailsViewModel {
        let repos = try makeRepositories()
        try repos.recurringItems.save(item)
        return ItemDetailsViewModel(
            item: item,
            repositories: repos,
            exchangeRateProvider: StaticExchangeRateProvider(),
            notificationScheduler: MockNotificationScheduler()
        )
    }

    @Test("startEditing seeds editTrialReminder from stored item")
    func startEditingSeedsTrialReminder() throws {
        let vm = try makeVM(item: makeItem(trialReminder: .sevenDaysBefore))
        vm.startEditing()
        #expect(vm.editTrialReminder == .sevenDaysBefore)
    }

    @Test("startEditing seeds .never when item has .never")
    func startEditingSeedsNever() throws {
        let vm = try makeVM(item: makeItem(trialReminder: .never))
        vm.startEditing()
        #expect(vm.editTrialReminder == .never)
    }

    @Test("saveChanges persists editTrialReminder = .threeDaysBefore")
    func saveChangesTrialReminder() throws {
        let vm = try makeVM(item: makeItem(trialReminder: .never))
        vm.startEditing()
        vm.editTrialReminder = .threeDaysBefore
        try vm.saveChanges()
        #expect(vm.item.trialReminder == .threeDaysBefore)
    }

    @Test("saveChanges persists editTrialReminder = .never")
    func saveChangesTrialReminderNever() throws {
        let vm = try makeVM(item: makeItem(trialReminder: .oneDayBefore))
        vm.startEditing()
        vm.editTrialReminder = .never
        try vm.saveChanges()
        #expect(vm.item.trialReminder == .never)
    }

    @Test("schedule(for:) called on saveChanges")
    func saveChangesSchedulesCalled() async throws {
        let mock = MockNotificationScheduler()
        let item = makeItem(trialReminder: .threeDaysBefore)
        let repos = try makeRepositories()
        try repos.recurringItems.save(item)
        let vm = ItemDetailsViewModel(
            item: item,
            repositories: repos,
            exchangeRateProvider: StaticExchangeRateProvider(),
            notificationScheduler: mock
        )
        vm.startEditing()
        vm.editTrialReminder = .sameDay
        try vm.saveChanges()
        await Task.yield()
        #expect(mock.scheduledIDs.contains(item.id))
    }

    @Test("cancel(for:) called on archive — removes both charge and trial identifiers")
    func archiveCancelsBoth() async throws {
        let mock = MockNotificationScheduler()
        let item = makeItem(trialReminder: .threeDaysBefore)
        let repos = try makeRepositories()
        try repos.recurringItems.save(item)
        let vm = ItemDetailsViewModel(
            item: item,
            repositories: repos,
            exchangeRateProvider: StaticExchangeRateProvider(),
            notificationScheduler: mock
        )
        try vm.archive()
        await Task.yield()
        // cancel(for:) is called once; the real scheduler removes both identifiers internally.
        #expect(mock.cancelledIDs.contains(item.id))
    }
}
