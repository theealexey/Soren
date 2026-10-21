import Foundation
import Testing
@testable import Soren

@MainActor
struct CalendarPresentationTests {
    private final class Repository: RecurringItemRepository {
        var items: [RecurringItem]
        init(_ items: [RecurringItem]) { self.items = items }
        func fetchAll() throws -> [RecurringItem] { items }
        func fetchActive() throws -> [RecurringItem] { items }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { [] }
        func fetch(id: UUID) throws -> RecurringItem? { nil }
        func save(_ item: RecurringItem) throws {}
        func update(_ item: RecurringItem) throws {}
        func delete(id: UUID) throws {}
        func saveAll(_ items: [RecurringItem]) throws {}
        func deleteAll() throws {}
    }

    private struct Rates: ExchangeRateProvider {
        func latestSnapshot() async throws -> ExchangeRateSnapshot { throw CancellationError() }
    }

    private func day(_ number: Int = 15) throws -> CivilDate {
        try CivilDate(year: 2026, month: 8, day: number)
    }

    private func date(_ number: Int = 15) throws -> Date {
        try BillingCivilDay.canonicalDate(for: day(number))
    }

    private func item(cycle: BillingCycle = .monthly) throws -> RecurringItem {
        RecurringItem(title: "Calendar QA", amount: 124, currencyCode: "RUB", billingCycle: cycle,
                      startDate: try date(1), nextChargeDate: try date())
    }

    private func event(trial: Bool = false) throws -> CalendarScheduleOccurrence {
        let item = try item()
        let event: RecurringScheduleEvent = trial
            ? .trialEnd(itemID: item.id, date: try date())
            : .scheduledCharge(itemID: item.id, date: try date(), money: try Money(amount: 124, currencyCode: "RUB"))
        return CalendarScheduleOccurrence(item: item, event: event, day: try day())
    }

    private func model(_ items: [RecurringItem]) throws -> CalendarViewModel {
        let now = try date()
        let defaults = try #require(UserDefaults(suiteName: "CalendarPresentationTests.\(UUID().uuidString)"))
        return CalendarViewModel(repository: Repository(items), preferences: UserPreferencesRepository(defaults: defaults),
                                 exchangeRateProvider: Rates(), now: { now }, calendar: BillingCivilDay.calendar)
    }

    @Test(arguments: [1, 2, 3, 4, 5])
    func marksCompressOnlyVisualOverflow(_ count: Int) throws {
        let occurrence = try event()
        let all = Array(repeating: occurrence, count: count) // Same provider/item must not be deduplicated.
        let presentation = CalendarDayPresentation(
            day: CalendarDay(date: try date(), isCurrentMonth: true, isToday: false),
            isSelected: true, occurrences: all
        )
        #expect(presentation.visibleMarks.count == min(count, 2))
        #expect(presentation.overflowCount == max(0, count - 2))
        #expect(presentation.occurrences == all)
        #expect(presentation.scheduledChargeCount == count)
    }

    @Test(arguments: [true, false])
    func todayIsIndependentOfSelection(_ selected: Bool) throws {
        let presentation = CalendarDayPresentation(
            day: CalendarDay(date: try date(), isCurrentMonth: true, isToday: true),
            isSelected: selected, occurrences: []
        )
        #expect(presentation.isToday)
        #expect(presentation.isSelected == selected)
        #expect(presentation.accessibilityLabel(calendar: BillingCivilDay.calendar).contains(String(localized: "Сегодня")))
    }

    @Test func outsideMonthCannotInteractOrShowMarks() throws {
        let presentation = CalendarDayPresentation(
            day: CalendarDay(date: try date(), isCurrentMonth: false, isToday: false),
            isSelected: false, occurrences: [try event()]
        )
        #expect(presentation.isInteractive == false)
        #expect(presentation.visibleMarks.isEmpty)
        #expect(presentation.overflowCount == 0)
    }

    @Test func trialAndChargeHaveSeparateAccessibleCountsAndMoney() throws {
        let trial = try event(trial: true)
        let charge = try event()
        let presentation = CalendarDayPresentation(
            day: CalendarDay(date: try date(), isCurrentMonth: true, isToday: false),
            isSelected: true, occurrences: [trial, charge]
        )
        #expect(presentation.trialEndCount == 1)
        #expect(presentation.scheduledChargeCount == 1)
        let label = presentation.accessibilityLabel(calendar: BillingCivilDay.calendar)
        #expect(label.contains(String(localized: "\(1) списаний")))
        #expect(label.contains(String(localized: "\(1) пробных")))
        #expect(trial.money == nil)
        #expect(CalendarPresentation.metadata(for: trial) == String(localized: "Пробный период заканчивается"))
        #expect(charge.money?.amount == 124)
    }

    @Test func selectedDayAndAgendaPreserveEveryOccurrence() throws {
        let vm = try model([item(), item()])
        vm.load()
        vm.selectDate(try date())
        #expect(vm.selectedDate == (try date()))
        #expect(vm.selectedDayOccurrences.count == 2)
        #expect(vm.monthlyAggregation?.total?.amount == 248)
        vm.selectDate(try date(16))
        #expect(vm.selectedDayOccurrences.isEmpty)
        #expect(vm.monthlyAggregation?.total?.amount == 248)
    }

    @Test func emptyMonthAndTrialMonthAreDifferentPresentationStates() throws {
        let empty = try model([])
        empty.load()
        #expect(empty.hasMonthlyEvents == false)
        #expect(empty.selectedDayOccurrences.isEmpty)
        var trial = try item()
        trial.status = .trial
        trial.autoRenew = false
        trial.endDate = try date()
        trial.trialEndDate = try date()
        let vm = try model([trial])
        vm.load()
        #expect(vm.hasMonthlyEvents)
        #expect(vm.hasMonthlyCharges == false)
        #expect(vm.selectedDayOccurrences.count == 1)
        #expect(vm.selectedDayOccurrences.first?.money == nil)
        #expect(vm.monthlyAggregation == nil)
    }

    @Test func previousRemainsDisabledAtCurrentMonth() throws {
        let vm = try model([])
        vm.load()
        #expect(vm.canNavigatePreviousMonth == false)
        let current = vm.displayedMonth
        vm.previousMonth()
        #expect(vm.displayedMonth == current)
        vm.nextMonth()
        #expect(vm.canNavigatePreviousMonth)
    }

    @Test func selectedHeadingUsesTodayOnlyForToday() throws {
        let today = CalendarDay(date: try date(), isCurrentMonth: true, isToday: true)
        #expect(CalendarPresentation.selectedDayTitle(day: today, calendar: BillingCivilDay.calendar) == String(localized: "Сегодня"))
        let other = CalendarDay(date: try date(16), isCurrentMonth: true, isToday: false)
        #expect(CalendarPresentation.selectedDayTitle(day: other, calendar: BillingCivilDay.calendar).contains("16"))
    }

    @Test func weeklyMonthTotalIsNotSelectedDayMoney() throws {
        let vm = try model([item(cycle: .weekly)])
        vm.load()
        #expect(vm.occurrencesByDay.values.flatMap { $0 }.count == 5)
        #expect(vm.monthlyAggregation?.total?.amount == 620)
        #expect(vm.selectedDayOccurrences.count == 1)
        #expect(vm.selectedDayOccurrences.first?.money?.amount == 124)
    }

    @Test(arguments: [
        ("ru_RU", 10, "Октябрь 2026 г."),
        ("ru_RU", 11, "Ноябрь 2026 г."),
        ("en_US", 10, "October 2026"),
        ("en_US", 11, "November 2026")
    ], ["UTC", "Europe/Stockholm", "America/Los_Angeles", "Asia/Tokyo"])
    func monthHeadingPreservesLocalizedSuffixSpacingAndCivilMonth(
        _ example: (locale: String, month: Int, expected: String), _ zone: String
    ) throws {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        let firstDay = try CivilDate(year: 2026, month: example.month, day: 1)
        let carrier = try BillingDatePresentation.pickerCarrier(for: firstDay, in: calendar.timeZone)
        let defaults = try #require(UserDefaults(suiteName: "CalendarMonthHeadingTests.\(UUID().uuidString)"))
        let vm = CalendarViewModel(
            repository: Repository([]), preferences: UserPreferencesRepository(defaults: defaults),
            exchangeRateProvider: Rates(), now: { carrier }, calendar: calendar
        )
        let displayedMonth = vm.displayedMonth

        #expect(vm.monthTitle(locale: Locale(identifier: example.locale)) == example.expected)
        #expect(vm.monthTitle == vm.monthTitle(locale: PresentationLocale.current))
        #expect(vm.displayedMonth == displayedMonth)
        #expect(try BillingCivilDay.civilDate(containing: displayedMonth, in: calendar.timeZone) == firstDay)
    }
}
