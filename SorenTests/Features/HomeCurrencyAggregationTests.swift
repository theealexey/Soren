import Foundation
import Testing
@testable import Soren

@Suite("Home Overview integration and currency coherence")
@MainActor
struct HomeCurrencyAggregationTests {
    private final class Repository: RecurringItemRepository {
        var items: [RecurringItem]
        var fetchError: Error?

        init(items: [RecurringItem]) { self.items = items }

        func fetchAll() throws -> [RecurringItem] {
            if let fetchError { throw fetchError }
            return items
        }
        func fetchActive() throws -> [RecurringItem] { try fetchAll().filter(\.status.countsInTotals) }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
            if let fetchError { throw fetchError }
            let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
            return items.filter { $0.nextChargeDate >= date && $0.nextChargeDate <= cutoff }
        }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
            try fetchAll().filter { $0.category == category }
        }
        func fetch(id: UUID) throws -> RecurringItem? { try fetchAll().first { $0.id == id } }
        func save(_ item: RecurringItem) throws { items.append(item) }
        func update(_ item: RecurringItem) throws {}
        func delete(id: UUID) throws { items.removeAll { $0.id == id } }
        func saveAll(_ items: [RecurringItem]) throws { self.items.append(contentsOf: items) }
        func deleteAll() throws { items.removeAll() }
    }

    private actor RecordingRates: ExchangeRateProvider {
        private let result: Result<ExchangeRateSnapshot, RateError>
        private var count = 0

        init(_ result: Result<ExchangeRateSnapshot, RateError>) { self.result = result }
        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            count += 1
            return try result.get()
        }
        func requests() -> Int { count }
    }

    private actor DeferredRates: ExchangeRateProvider {
        private var continuations: [CheckedContinuation<ExchangeRateSnapshot, Error>] = []
        private var requestCount = 0
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            let currentWaiters = waiters
            waiters.removeAll()
            currentWaiters.forEach { $0.resume() }
            return try await withCheckedThrowingContinuation { continuations.append($0) }
        }

        func waitForRequests(_ count: Int) async {
            guard requestCount < count else { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func resume(at index: Int, snapshot: ExchangeRateSnapshot) {
            guard continuations.indices.contains(index) else { return }
            continuations.remove(at: index).resume(returning: snapshot)
        }
    }

    private actor CurrencyRecorder {
        private var values: [String] = []
        func append(_ value: String) { values.append(value) }
        func last() -> String? { values.last }
    }

    private actor PlanSequence {
        private var values: [MonthlySubscriptionPlan]
        init(_ values: [MonthlySubscriptionPlan]) { self.values = values }
        func next() -> MonthlySubscriptionPlan? {
            guard !values.isEmpty else { return nil }
            return values.removeFirst()
        }
    }

    private enum RateError: Error { case unavailable }
    private enum RepositoryError: Error { case unavailable }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }

    private func today() throws -> Date {
        try #require(calendar().date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 12)))
    }

    private func date(day: Int, month: Int = 8) throws -> Date {
        try #require(calendar().date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)))
    }

    private func item(
        title: String,
        amount: Decimal = 100,
        currencyCode: String = "RUB",
        day: Int,
        month: Int = 8,
        status: ItemStatus = .active,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        archivedAt: Date? = nil
    ) throws -> RecurringItem {
        RecurringItem(
            title: title,
            providerID: nil,
            providerName: "",
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: .monthly,
            startDate: try date(day: 1),
            nextChargeDate: try date(day: day, month: month),
            autoRenew: autoRenew,
            endDate: endDate,
            status: status,
            archivedAt: archivedAt
        )
    }

    private func money(_ amount: Decimal, _ currency: String = "RUB") throws -> Money {
        try Money(amount: amount, currencyCode: currency)
    }

    private func plan(
        amount: Decimal,
        count: Int = 3,
        remaining: Decimal? = nil,
        remainingCount: Int? = nil,
        currency: String = "RUB"
    ) throws -> MonthlySubscriptionPlan {
        MonthlySubscriptionPlan(
            plannedTotal: try money(amount, currency),
            chargeCount: count,
            remainingTotal: try money(remaining ?? amount, currency),
            remainingChargeCount: remainingCount ?? count
        )
    }

    private func snapshot(rubRate: Decimal = 90) -> ExchangeRateSnapshot {
        let date = Date(timeIntervalSince1970: 1_786_610_400)
        return ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: date,
                rates: ["RUB": rubRate],
                fetchedAt: date
            ),
            freshness: .fresh
        )
    }

    private func preferences(currency: String = "RUB") throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suite = "HomeCurrencyAggregationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let repository = UserPreferencesRepository(defaults: defaults)
        repository.save(UserPreferences(
            defaultCurrencyCode: currency,
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))
        return (repository, defaults, suite)
    }

    private func viewModel<Provider: ExchangeRateProvider>(
        items: [RecurringItem] = [],
        provider: Provider,
        reportingCurrency: String = "RUB",
        plan: @escaping MonthlySubscriptionPlanCalculation,
        insight: @escaping OverviewInsightCalculation = { _, _, _, _ in nil }
    ) throws -> (HomeViewModel, UserDefaults, String, Repository) {
        let repository = Repository(items: items)
        let (preferences, defaults, suite) = try preferences(currency: reportingCurrency)
        let fixedToday = try today()
        return (
            HomeViewModel(
                getUpcomingCharges: GetUpcomingCharges(repository: repository),
                preferences: preferences,
                exchangeRateProvider: provider,
                calculateMonthlyPlan: plan,
                calculateOverviewInsight: insight,
                now: { fixedToday },
                calendar: calendar()
            ),
            defaults,
            suite,
            repository
        )
    }

    private func digits(_ value: String) -> String { String(value.filter(\.isNumber)) }

    // MARK: Insight mapping

    @Test("Annual Scale maps as the supplied financial insight")
    func annualScale() async throws {
        let monthly = try plan(amount: 797)
        let annual = OverviewInsight.annualScale(try money(9_564))
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in annual }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.kind == .annualScale)
        #expect(digits(vm.overviewInsight?.primary ?? "") == "9564")
    }

    @Test("Dense Week with total keeps amount and date range")
    func denseWeekTotal() async throws {
        let first = try date(day: 15)
        let last = try date(day: 20)
        let insight = OverviewInsight.denseWeek(.init(
            firstChargeDate: first,
            lastChargeDate: last,
            itemIDs: [UUID(), UUID(), UUID()],
            total: try money(797)
        ))
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.kind == .denseWeek)
        #expect(vm.overviewInsight?.supporting.contains("797") == true)
    }

    @Test("Dense Week without total never invents money")
    func denseWeekNoTotal() async throws {
        let insight = OverviewInsight.denseWeek(.init(
            firstChargeDate: try date(day: 15),
            lastChargeDate: try date(day: 20),
            itemIDs: [UUID(), UUID(), UUID()],
            total: nil
        ))
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.supporting.contains("₽") == false)
        #expect(vm.overviewInsight?.supporting.contains("15") == true)
    }

    @Test("Trial Attention without terms contains only the truthful title")
    func trialWithoutTerms() async throws {
        let insight = OverviewInsight.attention(.trialEnding(.init(
            itemID: UUID(),
            itemTitle: "Apple Music",
            trialEndDate: try date(day: 16),
            renewalTerms: nil
        )))
        let monthly = try plan(amount: 767)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.kind == .trialAttention)
        #expect(vm.overviewInsight?.supporting == "Apple Music")
    }

    @Test("Trial Attention includes only proven renewal terms")
    func trialWithTerms() async throws {
        let insight = OverviewInsight.attention(.trialEnding(.init(
            itemID: UUID(),
            itemTitle: "Apple Music",
            trialEndDate: try date(day: 14),
            renewalTerms: .init(amount: try money(169), billingCycle: .monthly)
        )))
        let monthly = try plan(amount: 169)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.supporting.contains("169") == true)
        #expect(vm.overviewInsight?.supporting.contains(String(localized: "затем")) == true)
    }

    @Test("Same-day Attention remains valid without aggregate money")
    func sameDayNoTotal() async throws {
        let insight = OverviewInsight.attention(.sameDayRenewals(.init(
            chargeDate: try date(day: 15),
            itemIDs: [UUID(), UUID(), UUID()],
            total: nil
        )))
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.kind == .sameDayAttention)
        #expect(vm.overviewInsight?.supporting.contains("₽") == false)
    }

    @Test("Same-day Attention maps a complete total")
    func sameDayTotal() async throws {
        let insight = OverviewInsight.attention(.sameDayRenewals(.init(
            chargeDate: try date(day: 15),
            itemIDs: [UUID(), UUID(), UUID()],
            total: try money(797)
        )))
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in insight }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.supporting.contains("797") == true)
    }

    @Test("Nil Domain insight stays nil")
    func nilInsight() async throws {
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight == nil)
    }

    @Test("ViewModel maps the supplied insight without re-selecting priority")
    func noPriorityDuplication() async throws {
        let supplied = OverviewInsight.denseWeek(.init(
            firstChargeDate: try date(day: 15),
            lastChargeDate: try date(day: 18),
            itemIDs: [UUID(), UUID(), UUID()],
            total: nil
        ))
        let monthly = try plan(amount: 797)
        let (vm, defaults, suite, _) = try viewModel(
            provider: RecordingRates(.failure(.unavailable)),
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in supplied }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.overviewInsight?.kind == .denseWeek)
    }

    // MARK: FX completeness

    @Test("Complete mixed-currency FX updates the Hero")
    func mixedFXHero() async throws {
        let provider = RecordingRates(.success(snapshot()))
        let items = [try item(title: "USD", amount: 2, currencyCode: "USD", day: 15)]
        let completePlan = try plan(amount: 180)
        let (vm, defaults, suite, _) = try viewModel(
            items: items,
            provider: provider,
            plan: { _, _, _, snapshot in
                snapshot == nil ? nil : completePlan
            }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(digits(vm.monthlyPlan.primary) == "180")
    }

    @Test("Missing FX leaves the Hero unavailable rather than partial")
    func missingFXHero() async throws {
        let provider = RecordingRates(.failure(.unavailable))
        let items = [try item(title: "USD", amount: 2, currencyCode: "USD", day: 15)]
        let (vm, defaults, suite, _) = try viewModel(
            items: items,
            provider: provider,
            plan: { _, _, _, _ in nil }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.monthlyPlan.primary == String(localized: "План недоступен"))
    }

    @Test("Missing FX is never converted to zero")
    func missingFXNotZero() async throws {
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in nil }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(!vm.monthlyPlan.primary.contains("0"))
    }

    @Test("One logical load requests at most one FX snapshot")
    func oneFXRequest() async throws {
        let provider = RecordingRates(.success(snapshot()))
        let completePlan = try plan(amount: 100)
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, snapshot in
                snapshot == nil ? nil : completePlan
            }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(await provider.requests() == 1)
    }

    @Test("Same-currency complete state skips FX")
    func sameCurrencySkipsFX() async throws {
        let provider = RecordingRates(.success(snapshot()))
        let monthly = try plan(amount: 100)
        let annual = OverviewInsight.annualScale(try money(1_200))
        let items = [try item(title: "RUB", amount: 100, day: 15)]
        let (vm, defaults, suite, _) = try viewModel(
            items: items,
            provider: provider,
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in annual }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(await provider.requests() == 0)
    }

    @Test("A truthful empty state skips FX")
    func emptySkipsFX() async throws {
        let provider = RecordingRates(.success(snapshot()))
        let monthly = try plan(amount: 0, count: 0, remainingCount: 0)
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(await provider.requests() == 0)
    }

    @Test("FX failure does not turn optional enrichment into a Home error")
    func fxFailureIsolated() async throws {
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in nil }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.isLoaded)
        #expect(!vm.hasError)
    }

    @Test("Stale FX completion cannot overwrite a newer load")
    func staleFXRevision() async throws {
        let provider = DeferredRates()
        let usd = try item(title: "USD", amount: 1, currencyCode: "USD", day: 15)
        let (vm, defaults, suite, _) = try viewModel(
            items: [usd],
            provider: provider,
            plan: { _, _, _, snapshot in
                guard let rate = snapshot?.rates["RUB"] else { return nil }
                let total = try Money(amount: rate, currencyCode: "RUB")
                return MonthlySubscriptionPlan(
                    plannedTotal: total,
                    chargeCount: 1,
                    remainingTotal: total,
                    remainingChargeCount: 1
                )
            }
        )
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldLoad = Task { await vm.load() }
        await provider.waitForRequests(1)
        let newLoad = Task { await vm.load(forceReload: true) }
        await provider.waitForRequests(2)

        await provider.resume(at: 1, snapshot: snapshot(rubRate: 200))
        await newLoad.value
        #expect(digits(vm.monthlyPlan.primary) == "200")

        await provider.resume(at: 0, snapshot: snapshot(rubRate: 100))
        await oldLoad.value
        #expect(digits(vm.monthlyPlan.primary) == "200")
    }

    @Test("Forced reload replaces Hero and Insight as one current snapshot")
    func forcedReload() async throws {
        let first = try plan(amount: 100)
        let second = try plan(amount: 200)
        let sequence = PlanSequence([first, second])
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in await sequence.next() }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        await vm.load(forceReload: true)
        #expect(digits(vm.monthlyPlan.primary) == "200")
    }

    @Test("Reporting currency is passed unchanged to the Domain calculations")
    func reportingCurrencyInput() async throws {
        let recorder = CurrencyRecorder()
        let monthly = try plan(amount: 10, currency: "USD")
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            reportingCurrency: "USD",
            plan: { _, _, currency, _ in
                await recorder.append(currency)
                return monthly
            }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(await recorder.last() == "USD")
    }

    // MARK: Eligibility and presentation details

    @Test("Excluded foreign subscriptions do not request FX")
    func excludedForeignSkipsFX() async throws {
        let paused = try item(
            title: "Paused USD",
            amount: 10,
            currencyCode: "USD",
            day: 15,
            status: .paused
        )
        let provider = RecordingRates(.success(snapshot()))
        let monthly = try plan(amount: 0, count: 0, remainingCount: 0)
        let (vm, defaults, suite, _) = try viewModel(
            items: [paused],
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(await provider.requests() == 0)
    }

    @Test("Paused subscriptions never appear in Upcoming")
    func pausedExcluded() async throws {
        let paused = try item(title: "Paused", day: 15, status: .paused)
        let provider = RecordingRates(.failure(.unavailable))
        let monthly = try plan(amount: 0, count: 0, remainingCount: 0)
        let (vm, defaults, suite, _) = try viewModel(
            items: [paused],
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.upcoming.rows.isEmpty)
    }

    @Test("A stale active charge rolls into the upcoming window")
    func staleDateRollover() async throws {
        let stale = try item(title: "Stale", day: 15, month: 7)
        let provider = RecordingRates(.failure(.unavailable))
        let monthly = try plan(amount: 100)
        let (vm, defaults, suite, _) = try viewModel(
            items: [stale],
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.upcoming.rows.first?.providerName == "Stale")
        #expect(vm.upcoming.rows.first?.chargeDate.contains("15") == true)
    }

    @Test("Expired finite subscriptions never appear in Upcoming")
    func expiredFiniteExcluded() async throws {
        let expired = try item(
            title: "Expired",
            day: 15,
            autoRenew: false,
            endDate: try date(day: 12)
        )
        let provider = RecordingRates(.failure(.unavailable))
        let monthly = try plan(amount: 0, count: 0, remainingCount: 0)
        let (vm, defaults, suite, _) = try viewModel(
            items: [expired],
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.upcoming.rows.isEmpty)
    }

    @Test("A zero Domain plan is rendered as the approved empty statement")
    func zeroPlan() async throws {
        let monthly = try plan(amount: 0, count: 0, remainingCount: 0)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.monthlyPlan.primaryStyle == .statement)
        #expect(vm.monthlyPlan.primary == String(localized: "overview.monthlyPlan.empty"))
        #expect(!vm.monthlyPlan.primary.contains("0"))
    }

    @Test("Decimal financial values preserve cents in presentation")
    func decimalPrecisionPresentation() async throws {
        let monthly = try plan(amount: Decimal(string: "19.99") ?? 0)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(digits(vm.monthlyPlan.primary) == "1999")
    }

    @Test("One charge uses localized singular copy")
    func singularChargeCopy() async throws {
        let monthly = try plan(amount: 100, count: 1, remainingCount: 1)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.monthlyPlan.leadingSupport == String(localized: "\(1) списаний"))
    }

    @Test("Multiple charges use localized plural copy")
    func pluralChargeCopy() async throws {
        let monthly = try plan(amount: 200, count: 2, remainingCount: 2)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.monthlyPlan.leadingSupport == String(localized: "\(2) списаний"))
    }

    @Test("Remaining charge count is retained in VoiceOver semantics")
    func remainingCountAccessibility() async throws {
        let monthly = try plan(amount: 500, count: 5, remaining: 200, remainingCount: 2)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.monthlyPlan.accessibilityLabel.contains("2"))
    }

    @Test("Upcoming dates use calendar and locale presentation")
    func upcomingDateFormatting() async throws {
        let charge = try item(title: "Charge", day: 18)
        let monthly = try plan(amount: 100)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            items: [charge],
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(vm.upcoming.rows.first?.chargeDate.contains("18") == true)
    }

    @Test("Published Home state is coherent across Hero Insight and Upcoming")
    func coherentPublishedState() async throws {
        let charge = try item(title: "Spotify", amount: 199, day: 15)
        let monthly = try plan(amount: 199, count: 1, remainingCount: 1)
        let annual = OverviewInsight.annualScale(try money(2_388))
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            items: [charge],
            provider: provider,
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in annual }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(digits(vm.screenState.monthlyPlan.primary) == "199")
        #expect(vm.screenState.overviewInsight?.kind == .annualScale)
        #expect(vm.screenState.upcoming.rows.count == 1)
    }

    @Test("Attention integrates beside a non-zero monthly plan")
    func coherentAttention() async throws {
        let monthly = try plan(amount: 767)
        let attention = OverviewInsight.attention(.trialEnding(.init(
            itemID: UUID(),
            itemTitle: "Apple Music",
            trialEndDate: try date(day: 16),
            renewalTerms: nil
        )))
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in attention }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(digits(vm.monthlyPlan.primary) == "767")
        #expect(vm.overviewInsight?.kind == .trialAttention)
    }

    @Test("Dense Week integrates beside a non-zero monthly plan")
    func coherentDenseWeek() async throws {
        let monthly = try plan(amount: 797)
        let dense = OverviewInsight.denseWeek(.init(
            firstChargeDate: try date(day: 15),
            lastChargeDate: try date(day: 20),
            itemIDs: [UUID(), UUID(), UUID()],
            total: try money(797)
        ))
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, _) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly },
            insight: { _, _, _, _ in dense }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        await vm.load()
        #expect(digits(vm.monthlyPlan.primary) == "797")
        #expect(vm.overviewInsight?.kind == .denseWeek)
    }

    @Test("A repository load failure uses the existing Home error state")
    func repositoryFailure() async throws {
        let monthly = try plan(amount: 100)
        let provider = RecordingRates(.failure(.unavailable))
        let (vm, defaults, suite, repository) = try viewModel(
            provider: provider,
            plan: { _, _, _, _ in monthly }
        )
        defer { defaults.removePersistentDomain(forName: suite) }
        repository.fetchError = RepositoryError.unavailable

        await vm.load()

        #expect(vm.hasError)
        #expect(!vm.isLoaded)
    }
}
