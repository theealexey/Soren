import Foundation
import SwiftData
import Testing
@testable import Soren

@MainActor
struct CalendarScheduleTests {
    private final class Repository: RecurringItemRepository {
        var items: [RecurringItem]
        var fetchCount = 0
        init(_ items: [RecurringItem]) { self.items = items }
        func fetchAll() throws -> [RecurringItem] { fetchCount += 1; return items }
        func fetchActive() throws -> [RecurringItem] { Issue.record("Calendar must fetch all candidates"); return [] }
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

    private func day(_ day: Int, month: Int = 8) throws -> CivilDate {
        try CivilDate(year: 2026, month: month, day: day)
    }

    private func date(_ day: Int, month: Int = 8) throws -> Date {
        try BillingCivilDay.canonicalDate(for: self.day(day, month: month))
    }

    private func item(_ number: Int = 1, cycle: BillingCycle = .monthly,
                      status: ItemStatus = .active, currency: String = "RUB") throws -> RecurringItem {
        let id = try #require(UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number)))
        return RecurringItem(id: id, title: "Item \(number)", amount: 100, currencyCode: currency,
                             billingCycle: cycle, startDate: try date(1), nextChargeDate: try date(1), status: status)
    }

    private func schedule(_ items: [RecurringItem], month: Int = 8) throws -> CalendarSchedule {
        try GetCalendarSchedule(repository: Repository(items)).execute(month: day(1, month: month), today: day(15))
    }

    private func viewModel(_ repository: some RecurringItemRepository, zone: String = "UTC") throws -> CalendarViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: zone))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 12)))
        let defaults = try #require(UserDefaults(suiteName: "CalendarScheduleTests.\(UUID().uuidString)"))
        let preferences = UserPreferencesRepository(defaults: defaults)
        return CalendarViewModel(repository: repository, preferences: preferences,
                                 exchangeRateProvider: Rates(), now: { now }, calendar: calendar)
    }

    @Test func monthlyAndFutureProjectionUseCanonicalRecurrence() throws {
        let result = try schedule([item()])
        #expect(result.occurrences.map(\.day) == [try day(1)])
        #expect(result.range.lowerBound == (try date(1)))
        #expect(result.range.upperBound == (try date(1, month: 9)))
        let future = try schedule([item()], month: 10)
        #expect(future.occurrences.map(\.day) == [try day(1, month: 10)])
    }

    @Test func everyWeeklyOccurrenceAndMonthlyMoneyArePreserved() throws {
        let repository = Repository([try item(cycle: .weekly)])
        let vm = try viewModel(repository)
        vm.load()
        #expect(vm.error == nil)
        #expect(vm.occurrencesByDay.values.flatMap { $0 }.count == 5)
        #expect(vm.monthlyAggregation?.total?.amount == 500)
        #expect(repository.fetchCount == 1)
        #expect(vm.occurrencesByDay[try day(1)]?.count == 1) // Past day inside current month.
    }

    @Test func sameDayItemsRemainSeparateAndSortByUUID() throws {
        let first = try item(1)
        let second = try item(2)
        let forward = try schedule([first, second])
        let reversed = try schedule([second, first])
        #expect(forward == reversed)
        #expect(forward.occurrences.map(\.item.id) == [first.id, second.id])
    }

    @Test func inclusiveEndAndStartBoundsArePreserved() throws {
        var finite = try item(cycle: .weekly)
        finite.autoRenew = false
        finite.startDate = try date(8)
        finite.endDate = try date(22)
        let result = try schedule([finite])
        #expect(result.occurrences.map(\.day) == [try day(8), try day(15), try day(22)])
    }

    @Test(arguments: [ItemStatus.active, .dueSoon, .dueToday, .overdue, .failed])
    func eligibleStatusesAreIncluded(_ status: ItemStatus) throws {
        #expect(try schedule([item(status: status)]).occurrences.count == 1)
    }

    @Test(arguments: [ItemStatus.paused, .cancelled, .archived])
    func excludedStatusesAreOmitted(_ status: ItemStatus) throws {
        #expect(try schedule([item(status: status)]).occurrences.isEmpty)
    }

    @Test func archiveTimestampAndExpiredFiniteAreExcluded() throws {
        var archived = try item(1)
        archived.archivedAt = try date(15)
        var expired = try item(2)
        expired.autoRenew = false
        expired.endDate = try date(14)
        #expect(try schedule([archived, expired]).occurrences.isEmpty)
    }

    @Test func trialBoundaryAndChargeOnSameDayRemainDistinct() throws {
        var trial = try item(status: .trial)
        trial.nextChargeDate = try date(20)
        trial.trialEndDate = try date(20)
        let result = try schedule([trial])
        #expect(result.occurrences.count == 2)
        #expect(result.occurrences.filter { $0.money == nil }.count == 1)
        #expect(result.occurrences.compactMap(\.money).map(\.amount) == [100])
        let vm = try viewModel(Repository([trial]))
        vm.load()
        vm.selectDate(try date(20))
        #expect(vm.selectedDayOccurrences.count == 2)
        #expect(vm.monthlyAggregation?.total?.amount == 100)
    }

    @Test func pureTrialDoesNotFabricateMoneyOrCompleteness() throws {
        var trial = try item(status: .trial)
        trial.autoRenew = false
        trial.endDate = try date(20)
        trial.trialEndDate = try date(20)
        let result = try schedule([trial])
        #expect(result.occurrences.count == 1)
        #expect(result.occurrences.compactMap(\.money).reduce(Decimal.zero) { $0 + $1.amount } == 0)
        #expect(result.monetaryCompleteness == .unavailable)
        let vm = try viewModel(Repository([trial]))
        vm.load()
        #expect(vm.monthlyAggregation == nil)
        #expect(vm.hasMonthlyCharges == false)
    }

    @Test func navigationCannotMoveBeforeCurrentMonth() throws {
        let vm = try viewModel(Repository([item()]))
        vm.load()
        let initial = vm.displayedMonth
        #expect(vm.canNavigatePreviousMonth == false)
        vm.previousMonth()
        #expect(vm.displayedMonth == initial)
        vm.nextMonth()
        #expect(vm.canNavigatePreviousMonth)
        #expect(vm.monthlyAggregation?.total?.amount == 100)
        vm.previousMonth()
        vm.previousMonth()
        #expect(vm.displayedMonth == initial)
    }

    @Test(arguments: ["Europe/Stockholm", "America/Los_Angeles", "Asia/Tokyo"])
    func groupingUsesCivilIdentityNotCanonicalInstantInLocalZone(_ zone: String) throws {
        var subscription = try item()
        subscription.nextChargeDate = try date(15)
        let vm = try viewModel(Repository([subscription]), zone: zone)
        vm.load()
        #expect(vm.occurrencesByDay[try day(15)]?.count == 1)
        let timeZone = try #require(TimeZone(identifier: zone))
        let carrier = try BillingDatePresentation.pickerCarrier(for: day(15), in: timeZone)
        vm.selectDate(carrier)
        #expect(vm.selectedDayOccurrences.map(\.day) == [try day(15)])
        #expect(vm.selectedDayAggregation?.total?.amount == 100)
    }

    @Test func missingFXIsNeverPresentedAsComplete() throws {
        let vm = try viewModel(Repository([item(1), item(2, currency: "USD")]))
        vm.load()
        guard case let .partial(total, missing, _) = vm.monthlyAggregation else {
            Issue.record("Expected partial FX coverage"); return
        }
        #expect(total.amount == 100)
        #expect(missing == ["USD"])
        let foreign = try viewModel(Repository([item(currency: "USD")]))
        foreign.load()
        guard case .unavailable = foreign.monthlyAggregation else {
            Issue.record("Expected unavailable FX coverage"); return
        }
    }

    @Test func invalidPersistedRowPropagatesTypedFailureWithoutEmptySuccess() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)
        let row = try RecurringItemMapper.toSD(item())
        row.billingDateEncodingVersion = 99
        context.insert(row)
        try context.save()
        let repository = SwiftDataRecurringItemRepository(container: container)
        do {
            _ = try GetCalendarSchedule(repository: repository).execute(month: day(1), today: day(15))
            Issue.record("Expected persisted metadata failure")
        } catch RecurringItemBillingDateAdapterError.unsupportedEncodingVersion(_, 99) {
            // The exact repository error crosses the Calendar boundary unchanged.
        }
        let vm = try viewModel(repository)
        vm.load()
        #expect(vm.error is RecurringItemBillingDateAdapterError)
        #expect(vm.isLoaded == false)
        #expect(vm.monthlyAggregation == nil)
    }
}
