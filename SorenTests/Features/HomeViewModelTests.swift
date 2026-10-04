import Foundation
import Testing
@testable import Soren

private typealias HomePlanStub = @Sendable (
    Date, Calendar, String, ExchangeRateSnapshot?
) async throws -> MonthlySubscriptionPlan?

@Suite("Overview money formatting")
struct OverviewMoneyFormattingTests {
    private let nonBreakingSpace = "\u{00A0}"

    @Test("Russian UI uses Russian grouping even when the device region is US")
    func russianGrouping() throws {
        let money = try Money(amount: 9_564, currencyCode: "RUB")
        let formatted = OverviewMoneyFormatter.string(
            money,
            locale: Locale(identifier: "ru_US")
        )

        #expect(formatted == "9\(nonBreakingSpace)564\(nonBreakingSpace)₽")
        #expect(!formatted.contains(","))
    }

    @Test("English UI retains its regional RUB currency conventions")
    func englishRegionalConventions() throws {
        let money = try Money(amount: 9_564, currencyCode: "RUB")

        let unitedStates = OverviewMoneyFormatter.string(
            money,
            locale: Locale(identifier: "en_US")
        )
        let russia = OverviewMoneyFormatter.string(
            money,
            locale: Locale(identifier: "en_RU")
        )

        #expect(unitedStates == "RUB\(nonBreakingSpace)9,564")
        #expect(russia == "9\(nonBreakingSpace)564\(nonBreakingSpace)RUB")
    }

    @Test("Annual Scale uses the shared Overview money policy")
    func annualScale() throws {
        let insight = OverviewInsight.annualScale(
            try Money(amount: 9_564, currencyCode: "RUB")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        let today = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 13
        )))

        let presentation = OverviewInsightPresentation.make(
            from: insight,
            today: today,
            calendar: calendar,
            locale: Locale(identifier: "ru_US")
        )

        #expect(presentation.primary == "9\(nonBreakingSpace)564\(nonBreakingSpace)₽")
    }
}

@Suite("HomeViewModel production Overview")
@MainActor
struct HomeViewModelTests {
    private final class Repository: RecurringItemRepository {
        var items: [RecurringItem]

        init(_ items: [RecurringItem] = []) { self.items = items }

        func fetchAll() throws -> [RecurringItem] { items }
        func fetchActive() throws -> [RecurringItem] { items.filter(\.status.countsInTotals) }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
            let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
            return items.filter { $0.nextChargeDate >= date && $0.nextChargeDate <= cutoff }
        }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
            items.filter { $0.category == category }
        }
        func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
        func save(_ item: RecurringItem) throws { items.append(item) }
        func update(_ item: RecurringItem) throws {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[index] = item
        }
        func delete(id: UUID) throws { items.removeAll { $0.id == id } }
        func saveAll(_ items: [RecurringItem]) throws { self.items.append(contentsOf: items) }
        func deleteAll() throws { items.removeAll() }
    }

    private actor UnavailableRates: ExchangeRateProvider {
        func latestSnapshot() async throws -> ExchangeRateSnapshot { throw RateError.unavailable }
    }

    private enum RateError: Error { case unavailable }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }

    private func today() throws -> Date {
        try #require(calendar().date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 12)))
    }

    private func date(day: Int) throws -> Date {
        try #require(calendar().date(from: DateComponents(year: 2026, month: 8, day: day, hour: 12)))
    }

    private func item(
        title: String,
        providerName: String = "",
        providerID: String? = nil,
        amount: Decimal = 199,
        currencyCode: String = "RUB",
        day: Int,
        status: ItemStatus = .active,
        trialEndDate: Date? = nil,
        archivedAt: Date? = nil
    ) throws -> RecurringItem {
        RecurringItem(
            title: title,
            providerID: providerID,
            providerName: providerName,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: .monthly,
            startDate: try date(day: 1),
            nextChargeDate: try date(day: day),
            trialEndDate: trialEndDate,
            status: status,
            archivedAt: archivedAt
        )
    }

    private func preferences() throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suite = "HomeViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let repository = UserPreferencesRepository(defaults: defaults)
        repository.save(UserPreferences(
            defaultCurrencyCode: "RUB",
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))
        return (repository, defaults, suite)
    }

    private func viewModel(
        items: [RecurringItem] = [],
        plan: @escaping HomePlanStub,
        snapshotCalculation: CurrentMonthSnapshotCalculation? = nil,
        insight: @escaping OverviewInsightCalculation = { _, _, _, _ in nil }
    ) throws -> (HomeViewModel, UserDefaults, String) {
        let (preferences, defaults, suite) = try preferences()
        let repository = Repository(items)
        let fixedToday = try today()
        let calendar = calendar()
        return (
            HomeViewModel(
                getUpcomingCharges: GetUpcomingCharges(repository: repository),
                preferences: preferences,
                exchangeRateProvider: UnavailableRates(),
                calculateCurrentMonth: snapshotCalculation ?? { today, calendar, code, rates in
                    CurrentMonthSubscriptionPlanSnapshot(
                        plan: try await plan(today, calendar, code, rates),
                        scheduledCharges: [],
                        statusCounts: SubscriptionStatusCounts(active: 0, trial: 0, paused: 0)
                    )
                },
                calculateOverviewInsight: insight,
                now: { fixedToday },
                calendar: calendar
            ),
            defaults,
            suite
        )
    }

    private func zeroPlan(currency: String = "RUB") throws -> MonthlySubscriptionPlan {
        let zero = try Money(amount: 0, currencyCode: currency)
        return MonthlySubscriptionPlan(
            plannedTotal: zero,
            chargeCount: 0,
            remainingTotal: zero,
            remainingChargeCount: 0
        )
    }

    @Test("Empty repository renders the approved monthly statement and no Upcoming rows")
    func emptyRepository() async throws {
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in zero })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.isLoaded)
        #expect(!viewModel.hasError)
        #expect(viewModel.monthlyPlan.primary == String(localized: "overview.monthlyPlan.empty"))
        #expect(viewModel.monthlyPlan.primary != String(localized: "Нет запланированных списаний"))
        #expect(viewModel.monthlyPlan.primaryStyle == .statement)
        #expect(viewModel.monthlyPlan.leadingSupport.isEmpty)
        #expect(!viewModel.monthlyPlan.primary.contains("0"))
        #expect(viewModel.upcoming.rows.isEmpty)
    }

    @Test("A valid monthly plan maps all four Domain values truthfully")
    func validPlanMapping() async throws {
        let plan = MonthlySubscriptionPlan(
            plannedTotal: try Money(amount: 1_596, currencyCode: "RUB"),
            chargeCount: 12,
            remainingTotal: try Money(amount: 347, currencyCode: "RUB"),
            remainingChargeCount: 3
        )
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in plan })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.monthlyPlan.primary.filter(\.isNumber) == "1596")
        #expect(viewModel.monthlyPlan.leadingSupport.contains("12"))
        #expect(viewModel.monthlyPlan.trailingSupportLabel == String(localized: "Осталось"))
        #expect(viewModel.monthlyPlan.trailingSupportValue?.filter(\.isNumber) == "347")
        #expect(viewModel.monthlyPlan.accessibilityLabel.contains("3"))
    }

    @Test("Unavailable money keeps snapshot schedule and lifecycle counts")
    func partialSnapshotMapping() async throws {
        let occurrenceDate = try date(day: 20)
        let occurrence = ScheduledChargeOccurrence(itemID: UUID(), date: occurrenceDate)
        let snapshot = CurrentMonthSubscriptionPlanSnapshot(
            plan: nil,
            scheduledCharges: [occurrence],
            statusCounts: SubscriptionStatusCounts(active: 4, trial: 2, paused: 1)
        )
        let (viewModel, defaults, suite) = try viewModel(
            plan: { _, _, _, _ in nil },
            snapshotCalculation: { _, _, _, _ in snapshot }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.monthlyPlan.primary == String(localized: "План недоступен"))
        #expect(viewModel.monthSchedule?.year == 2026)
        #expect(viewModel.monthSchedule?.month == 8)
        #expect(viewModel.monthSchedule?.daysInMonth == 31)
        #expect(viewModel.monthSchedule?.todayDay == 13)
        #expect(viewModel.monthSchedule?.occurrences == [
            MonthSchedulePresentation.Occurrence(itemID: occurrence.itemID, day: 20)
        ])
        #expect(viewModel.statusCounts == snapshot.statusCounts)
    }

    @Test("Repeated canonical charges keep distinct rows and item navigation identity")
    func repeatedUpcomingRows() async throws {
        let recurring = RecurringItem(
            title: "Weekly",
            amount: 100,
            billingCycle: .weekly,
            startDate: try date(day: 1),
            nextChargeDate: try date(day: 1)
        )
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(
            items: [recurring],
            plan: { _, _, _, _ in zero }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.upcoming.rows.count == 3)
        #expect(viewModel.upcoming.rows.map(\.item.id) == Array(repeating: recurring.id, count: 3))
        #expect(Set(viewModel.upcoming.rows.map(\.id)).count == 3)
        #expect(viewModel.upcoming.rows.map(\.scheduledDate) == [
            try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 8, day: 15)),
            try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 8, day: 22)),
            try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 8, day: 29)),
        ])
    }

    @Test("Hero omits a redundant remaining value when the entire plan is ahead")
    func completePlanRemaining() async throws {
        let total = try Money(amount: 797, currencyCode: "RUB")
        let plan = MonthlySubscriptionPlan(
            plannedTotal: total,
            chargeCount: 3,
            remainingTotal: total,
            remainingChargeCount: 3
        )
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in plan })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.monthlyPlan.leadingSupport.contains("3"))
        #expect(viewModel.monthlyPlan.trailingSupportLabel == nil)
        #expect(viewModel.monthlyPlan.trailingSupportValue == nil)
        #expect(!viewModel.monthlyPlan.accessibilityLabel.contains(String(localized: "Осталось")))
    }

    @Test("Nil monthly plan never becomes fake zero money")
    func unavailablePlan() async throws {
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in nil })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.monthlyPlan.primary == String(localized: "План недоступен"))
        #expect(!viewModel.monthlyPlan.primary.contains("0"))
        #expect(viewModel.monthlyPlan.primaryStyle == .statement)
    }

    @Test("The actual calendar month drives the header while the Hero uses its contextual label")
    func currentMonthLabels() async throws {
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in zero })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.monthLabel == "Август 2026")
        #expect(viewModel.monthlyPlan.title == String(localized: "overview.monthlyPlan.scheduled"))
    }

    @Test("Upcoming rows are limited to three and sorted by effective date")
    func upcomingLimitAndOrder() async throws {
        let items = try [5, 2, 9, 1].map { day in
            try item(title: "Day \(day)", day: 13 + day)
        }
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(
            items: items,
            plan: { _, _, _, _ in zero }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.upcoming.rows.map(\.providerName) == ["Day 1", "Day 2", "Day 5"])
    }

    @Test("Paused cancelled and archived subscriptions never enter Upcoming")
    func upcomingEligibility() async throws {
        let items = [
            try item(title: "Paused", day: 14, status: .paused),
            try item(title: "Cancelled", day: 15, status: .cancelled),
            try item(title: "Archived", day: 16, status: .archived),
            try item(title: "Active", day: 17),
        ]
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(
            items: items,
            plan: { _, _, _, _ in zero }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        let rows = viewModel.upcoming.rows
        #expect(rows.count == 3)
        #expect(rows.allSatisfy { $0.item.id == items[3].id })
        #expect(rows.map(\.providerName) == ["Active", "Active", "Active"])
        #expect(Set(rows.map(\.scheduledDate)).count == rows.count)
    }

    @Test("Trial with a real upcoming charge remains visible")
    func upcomingTrial() async throws {
        let trial = try item(
            title: "Trial", day: 16, status: .trial, trialEndDate: date(day: 16)
        )
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(
            items: [trial],
            plan: { _, _, _, _ in zero }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.upcoming.rows.first?.providerName == "Trial")
    }

    @Test("Upcoming row exposes provider identity and one combined accessibility label")
    func upcomingProviderIdentity() async throws {
        let spotify = try item(
            title: "Spotify Индивидуальный",
            providerName: "Spotify",
            providerID: "spotify",
            day: 15
        )
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(
            items: [spotify],
            plan: { _, _, _, _ in zero }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        let row = try #require(viewModel.upcoming.rows.first)
        #expect(row.providerName == "Spotify")
        #expect(row.accessibilityLabel == [row.providerName, row.chargeDate, row.amount].joined(separator: ", "))
    }

    @Test("One selected Domain insight maps into one presentation value")
    func selectedInsight() async throws {
        let zero = try zeroPlan()
        let annual = OverviewInsight.annualScale(try Money(amount: 9_564, currencyCode: "RUB"))
        let (viewModel, defaults, suite) = try viewModel(
            plan: { _, _, _, _ in zero },
            insight: { _, _, _, _ in annual }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.overviewInsight?.kind == .annualScale)
        #expect(viewModel.screenState.overviewInsight == viewModel.overviewInsight)
    }

    @Test("Nil Domain insight collapses without placeholder state")
    func nilInsight() async throws {
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in zero })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.overviewInsight == nil)
    }

    @Test("Non-forced repeated load is idempotent")
    func repeatedLoad() async throws {
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in zero })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()
        let first = viewModel.screenState
        await viewModel.load()

        #expect(viewModel.screenState == first)
    }

    @Test("Screen snapshot contains only the replacement Overview state")
    func screenStateShape() async throws {
        let zero = try zeroPlan()
        let (viewModel, defaults, suite) = try viewModel(plan: { _, _, _, _ in zero })
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.load()

        #expect(viewModel.screenState.monthlyPlan == viewModel.monthlyPlan)
        #expect(viewModel.screenState.upcoming == viewModel.upcoming)
        #expect(viewModel.screenState.isLoaded)
    }
}

@Suite("GetUpcomingCharges")
@MainActor
struct GetUpcomingChargesTests {
    @Test("Canonical one-year schedule returns the nearest occurrences")
    func nearestCanonicalOccurrences() throws {
        let repository = HomeViewModelTestsRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13)))
        repository.items = [
            RecurringItem(
                title: "Day3",
                amount: 100,
                billingCycle: .annual,
                startDate: now,
                nextChargeDate: try #require(calendar.date(byAdding: .day, value: 3, to: now))
            ),
            RecurringItem(
                title: "Day10",
                amount: 100,
                billingCycle: .annual,
                startDate: now,
                nextChargeDate: try #require(calendar.date(byAdding: .day, value: 10, to: now))
            ),
        ]

        let result = try GetUpcomingCharges(repository: repository)
            .execute(from: now, calendar: calendar)
        #expect(result.map(\.item.title) == ["Day3", "Day10"])
    }

    @Test("No real scheduled charges returns no Upcoming rows")
    func noCharges() throws {
        let repository = HomeViewModelTestsRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13)))
        repository.items = [RecurringItem(
            title: "Tomorrow",
            amount: 100,
            nextChargeDate: try #require(calendar.date(byAdding: .day, value: 1, to: now)),
            status: .paused
        )]

        let result = try GetUpcomingCharges(repository: repository)
            .execute(from: now, calendar: calendar)
        #expect(result.isEmpty)
    }
}

@Suite("GetActiveTrials")
@MainActor
struct GetActiveTrialsTests {
    @Test("Only trial status with future trialEndDate qualifies")
    func onlyActiveTrials() throws {
        let repository = HomeViewModelTestsRepository()
        let now = try canonicalTestDay(1)
        repository.items = [
            RecurringItem(
                title: "Trial",
                amount: 100,
                nextChargeDate: now,
                trialEndDate: BillingCivilDay.calendar.date(byAdding: .day, value: 3, to: now),
                status: .trial
            ),
            RecurringItem(
                title: "Active",
                amount: 100,
                nextChargeDate: now,
                trialEndDate: BillingCivilDay.calendar.date(byAdding: .day, value: 3, to: now),
                status: .active
            ),
        ]

        let result = try GetActiveTrials(repository: repository, now: { now }, timeZone: { .gmt }).execute()
        #expect(result.map(\.title) == ["Trial"])
    }
}

@MainActor
private final class HomeViewModelTestsRepository: RecurringItemRepository {
    var items: [RecurringItem] = []
    func fetchAll() throws -> [RecurringItem] { items }
    func fetchActive() throws -> [RecurringItem] { items.filter(\.status.countsInTotals) }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
        let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return items.filter { $0.nextChargeDate >= date && $0.nextChargeDate <= cutoff }
    }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        items.filter { $0.category == category }
    }
    func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
    func save(_ item: RecurringItem) throws { items.append(item) }
    func update(_ item: RecurringItem) throws {}
    func delete(id: UUID) throws { items.removeAll { $0.id == id } }
    func saveAll(_ items: [RecurringItem]) throws { self.items.append(contentsOf: items) }
    func deleteAll() throws { items.removeAll() }
}
