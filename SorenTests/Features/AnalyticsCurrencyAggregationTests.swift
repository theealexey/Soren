import Foundation
import Testing
@testable import Soren

@Suite("Analytics currency aggregation")
@MainActor
struct AnalyticsCurrencyAggregationTests {
    @MainActor
    private final class InMemoryRecurringItemRepository: RecurringItemRepository {
        private var items: [RecurringItem]

        init(items: [RecurringItem]) {
            self.items = items
        }

        func fetchAll() throws -> [RecurringItem] { items }
        func fetchActive() throws -> [RecurringItem] { items }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
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

    private enum RateProviderError: Error, Sendable {
        case unavailable
    }

    private enum RateResponse: Sendable {
        case success(ExchangeRateSnapshot)
        case failure(RateProviderError)
    }

    private actor RecordingExchangeRateProvider: ExchangeRateProvider {
        private var responses: [RateResponse]
        private var requestCount = 0

        init(responses: [RateResponse]) {
            self.responses = responses
        }

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            guard !responses.isEmpty else { throw RateProviderError.unavailable }
            switch responses.removeFirst() {
            case let .success(snapshot): return snapshot
            case let .failure(error): throw error
            }
        }

        func requests() -> Int { requestCount }
    }

    private actor ControlledExchangeRateProvider: ExchangeRateProvider {
        private var requestCount = 0
        private var pending: [Int: CheckedContinuation<ExchangeRateSnapshot, Error>] = [:]

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            let index = requestCount
            requestCount += 1
            return try await withCheckedThrowingContinuation { continuation in
                pending[index] = continuation
            }
        }

        func waitForRequests(_ expectedCount: Int) async {
            while requestCount < expectedCount {
                await Task.yield()
            }
        }

        func succeedRequest(at index: Int, with snapshot: ExchangeRateSnapshot) {
            pending.removeValue(forKey: index)?.resume(returning: snapshot)
        }

        func requests() -> Int { requestCount }
    }

    private struct PreferencesFixture {
        let repository: UserPreferencesRepository
        let defaults: UserDefaults
        let suiteName: String

        func save(currencyCode: String) {
            repository.save(UserPreferences(
                defaultCurrencyCode: currencyCode,
                defaultChargeReminder: .threeDaysBefore,
                chargeAlertDays: 3,
                trialAlertDays: 3
            ))
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func preferences(currencyCode: String = "RUB") throws -> PreferencesFixture {
        let suiteName = "AnalyticsCurrencyAggregationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let fixture = PreferencesFixture(
            repository: UserPreferencesRepository(defaults: defaults),
            defaults: defaults,
            suiteName: suiteName
        )
        fixture.save(currencyCode: currencyCode)
        return fixture
    }

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value))
    }

    private func snapshot(
        rubRate: Decimal = 90,
        extraRates: [String: Decimal] = [:],
        freshness: ExchangeRateFreshness = .fresh
    ) -> ExchangeRateSnapshot {
        let now = Date.now
        var rates = extraRates
        rates["RUB"] = rubRate
        return ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: now.addingTimeInterval(-3_600),
                rates: rates,
                fetchedAt: now
            ),
            freshness: freshness
        )
    }

    private func item(
        title: String,
        amount: Decimal,
        currencyCode: String,
        cycle: BillingCycle = .monthly,
        category: ItemCategory = .other,
        providerID: String? = nil,
        providerName: String? = nil,
        nextChargeDate: Date = .now,
        usageStatus: UsageStatus = .unknown
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            providerID: providerID,
            providerName: providerName ?? title,
            category: category,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: cycle,
            startDate: BillingCivilDay.calendar.startOfDay(for: nextChargeDate),
            nextChargeDate: BillingCivilDay.calendar.startOfDay(for: nextChargeDate),
            usageStatus: usageStatus
        )
    }

    private func viewModel(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: any ExchangeRateProvider
    ) -> AnalyticsViewModel {
        AnalyticsViewModel(
            getCurrentObligations: GetAnalyticsCurrentObligations(
                repository: InMemoryRecurringItemRepository(items: items)
            ),
            getForecast: GetAnalyticsForecast(repository: InMemoryRecurringItemRepository(items: items)),
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: provider
        )
    }

    private func refresh(_ viewModel: AnalyticsViewModel) async {
        await viewModel.refreshCurrencyAggregation(revision: viewModel.aggregationRevision)
    }

    @Test("Mixed RUB and USD aggregate completely after one conversion snapshot")
    func mixedCurrenciesCompleteAggregation() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 500, currencyCode: "RUB"),
                item(title: "USD", amount: 10, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.monthlyAggregation?.isComplete == true)
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 1_400)
        #expect(vm.screenState.monthlyAggregation?.total?.currencyCode == "RUB")
    }

    @Test("Same-currency Analytics never requests FX")
    func sameCurrencyDoesNotRequestFX() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(title: "A", amount: 100, currencyCode: "RUB"),
                item(title: "B", amount: 500, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.monthlyAggregation?.total?.amount == 600)
        #expect(await provider.requests() == 0)
    }

    @Test("Missing rate never falls back to the raw foreign number")
    func missingRateHasNoRawFallback() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 500, currencyCode: "RUB"),
                item(title: "GBP", amount: 100, currencyCode: "GBP")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.monthlyAggregation?.total?.amount == 500)
        #expect(vm.screenState.monthlyAggregation?.total?.amount != 600)
    }

    @Test("Partial state retains every missing currency code")
    func partialRetainsMissingCurrencyCodes() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: 28_800)))
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 500, currencyCode: "RUB"),
                item(title: "EUR", amount: 10, currencyCode: "EUR"),
                item(title: "GBP", amount: 20, currencyCode: "GBP")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case let .partial(total, codes, metadata) = vm.screenState.monthlyAggregation else {
            Issue.record("Expected partial Analytics aggregation")
            return
        }
        #expect(total.amount == 500)
        #expect(codes == ["EUR", "GBP"])
        #expect(metadata == nil)
    }

    @Test("Foreign-only unavailable data is not represented as zero")
    func unavailableIsNotZero() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: 28_800)))
        ])
        let vm = viewModel(
            items: [item(title: "GBP", amount: 10, currencyCode: "GBP")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case let .unavailable(_, missingCodes, _, metadata) = vm.screenState.monthlyAggregation else {
            Issue.record("Expected unavailable Analytics aggregation")
            return
        }
        #expect(missingCodes == ["GBP"])
        #expect(metadata == nil)
        #expect(vm.screenState.monthlyAggregation?.total == nil)
        #expect(!vm.screenState.isEmpty)
    }

    @Test("Stale snapshot metadata remains visible in Analytics state")
    func staleMetadataIsPreserved() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let age: TimeInterval = 28_800
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: age)))
        ])
        let vm = viewModel(
            items: [item(title: "USD", amount: 10, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.monthlyAggregation?.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("Category totals are grouped only after conversion")
    func categoryTotalsUseConvertedValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "Video", amount: 10, currencyCode: "USD", category: .video),
                item(title: "Cloud", amount: 500, currencyCode: "RUB", category: .cloud)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.categoryBreakdown.first { $0.category == .video }?.monthlyTotal == 900)
        #expect(vm.screenState.categoryBreakdown.first { $0.category == .cloud }?.monthlyTotal == 500)
    }

    @Test("Provider totals are grouped by provider identity after conversion")
    func providerTotalsUseConvertedValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(
                    title: "Service A",
                    amount: 10,
                    currencyCode: "USD",
                    providerID: "provider_a",
                    providerName: "Provider A"
                ),
                item(
                    title: "Service B",
                    amount: 100,
                    currencyCode: "RUB",
                    providerID: "provider_a",
                    providerName: "Provider A"
                )
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        let group = try #require(vm.screenState.providerBreakdown.first)
        #expect(group.id == "provider_a")
        #expect(group.monthlyTotal == 1_000)
        #expect(group.itemCount == 2)
    }

    @Test("Top subscription ranking compares converted monthly contributions")
    func topRankingUsesConvertedValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "USD winner", amount: 20, currencyCode: "USD"),
                item(title: "Raw-number winner", amount: 1_000, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.topItems.first?.title == "USD winner")
        #expect(vm.screenState.topItems.first?.monthlyAmount == 1_800)
    }

    @Test("Category percentages are produced only from a complete total")
    func completePercentagesUseComparableTotal() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "Video", amount: 10, currencyCode: "USD", category: .video),
                item(title: "Cloud", amount: 900, currencyCode: "RUB", category: .cloud)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        let proportion = vm.screenState.categoryBreakdown.reduce(0.0) { $0 + $1.proportion }
        #expect(abs(proportion - 1.0) < 0.000_001)
    }

    @Test("Partial aggregation suppresses rankings percentages charts and trends")
    func partialSuppressesComparativeOutputs() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 500, currencyCode: "RUB"),
                item(title: "GBP", amount: 100, currencyCode: "GBP")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.categoryBreakdown.isEmpty)
        #expect(vm.screenState.providerBreakdown.isEmpty)
        #expect(vm.screenState.topItems.isEmpty)
        #expect(vm.screenState.monthlyProjections.isEmpty)
        #expect(vm.screenState.trendComparison == nil)
        #expect(vm.screenState.unusedMonthlyCost == nil)
    }

    @Test("Trend comparison uses complete reporting-currency month values")
    func trendUsesComparableValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [item(title: "USD", amount: 10, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        let trend = try #require(vm.screenState.trendComparison)
        #expect(trend.earlierTotal == 900)
        #expect(trend.laterTotal == 900)
        #expect(trend.delta == 0)
        #expect(trend.currencyCode == "RUB")
    }

    @Test("One Analytics revision loads one snapshot for every grouping")
    func oneRevisionUsesOneSnapshot() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "USD A", amount: 10, currencyCode: "USD", category: .video),
                item(title: "USD B", amount: 20, currencyCode: "USD", category: .cloud)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)
        await refresh(vm)

        #expect(await provider.requests() == 1)
        #expect(!vm.screenState.categoryBreakdown.isEmpty)
        #expect(!vm.screenState.providerBreakdown.isEmpty)
        #expect(!vm.screenState.monthlyProjections.isEmpty)
    }

    @Test("Reporting currency change starts a new complete revision")
    func reportingCurrencyChangeRecalculates() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let sharedSnapshot = snapshot()
        let provider = RecordingExchangeRateProvider(responses: [
            .success(sharedSnapshot),
            .success(sharedSnapshot)
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 900, currencyCode: "RUB"),
                item(title: "USD", amount: 10, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)
        let rubRevision = vm.aggregationRevision
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 1_800)

        fixture.save(currencyCode: "USD")
        vm.load(forceReload: true)
        await refresh(vm)

        #expect(vm.aggregationRevision > rubRevision)
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 20)
        #expect(vm.screenState.monthlyAggregation?.total?.currencyCode == "USD")
        #expect(await provider.requests() == 2)
    }

    @Test("Obsolete asynchronous snapshot cannot overwrite a newer revision")
    func obsoleteSnapshotCannotOverwriteNewerRevision() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let provider = ControlledExchangeRateProvider()
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 900, currencyCode: "RUB"),
                item(title: "USD", amount: 10, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        let oldRevision = vm.aggregationRevision
        let oldTask = Task { await vm.refreshCurrencyAggregation(revision: oldRevision) }
        await provider.waitForRequests(1)

        fixture.save(currencyCode: "USD")
        vm.load(forceReload: true)
        let newRevision = vm.aggregationRevision
        let newTask = Task { await vm.refreshCurrencyAggregation(revision: newRevision) }
        await provider.waitForRequests(2)

        await provider.succeedRequest(at: 1, with: snapshot(rubRate: 100))
        await newTask.value
        await provider.succeedRequest(at: 0, with: snapshot(rubRate: 50))
        await oldTask.value

        #expect(vm.screenState.monthlyAggregation?.total?.currencyCode == "USD")
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 19)
        #expect(vm.screenState.monthlyProjections.allSatisfy { $0.total == 19 })
        #expect(await provider.requests() == 2)
    }

    @Test("Original item amount and currency remain authoritative")
    func originalItemRemainsUnchanged() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let original = item(title: "Original", amount: 12, currencyCode: "USD")
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [original],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        let navigationItem = try #require(vm.screenState.topItems.first?.navigationItem)
        #expect(navigationItem.amount == original.amount)
        #expect(navigationItem.currencyCode == original.currencyCode)
        #expect(vm.screenState.topItems.first?.monthlyAmount == 1_080)
    }

    @Test("Billing-cycle normalization happens before ranking and aggregation")
    func billingCycleNormalizationPrecedesRanking() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot(rubRate: 2))])
        let annual = item(title: "Annual", amount: 1_200, currencyCode: "USD", cycle: .annual)
        let monthly = item(title: "Monthly", amount: 300, currencyCode: "RUB")
        let vm = viewModel(
            items: [annual, monthly],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        let expectedAnnual = annual.monthlyEquivalent * 2
        #expect(vm.screenState.topItems.first?.title == "Monthly")
        #expect(vm.screenState.topItems.first { $0.title == "Annual" }?.monthlyAmount == expectedAnnual)
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 300 + expectedAnnual)
    }

    @Test("Forecast chart buckets use the shared converted snapshot")
    func forecastBucketsUseConvertedValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = viewModel(
            items: [
                item(title: "USD", amount: 10, currencyCode: "USD"),
                item(title: "RUB", amount: 100, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.screenState.monthlyProjections.count == 6)
        #expect(vm.screenState.monthlyProjections.allSatisfy { $0.total == 1_000 })
        #expect(await provider.requests() == 1)
    }
}

// MARK: - Canonical Six-Month Forecast

extension AnalyticsCurrencyAggregationTests {
    @Test("Current-obligation status policy is independent of fetchActive", arguments: ItemStatus.allCases)
    func currentObligationStatus(status: ItemStatus) throws {
        let source = try scheduledItem(status: status)
        let repository = ForecastRepository([source])
        let result = try GetAnalyticsCurrentObligations(repository: repository).execute(today: civil(2026, 10, 21))
        let included = [.active, .dueSoon, .dueToday, .overdue, .failed].contains(status)
        #expect(result.map(\.id) == (included ? [source.id] : []))
        #expect(repository.allReads == 1)
        #expect(repository.activeReads == 0)
        let unchangedActive = try GetActiveItems(repository: repository).execute()
        let active = [.active, .dueSoon, .dueToday, .trial].contains(status)
        #expect(unchangedActive.map(\.id) == (active ? [source.id] : []))
    }

    @Test("Current obligations have inclusive Gregorian lifecycle bounds", arguments: [
        (20, nil, true), (21, nil, true), (22, nil, false),
        (19, 20, false), (19, 21, true), (19, 22, true)
    ] as [(Int, Int?, Bool)])
    func currentObligationDates(startDay: Int, endDay: Int?, included: Bool) throws {
        var source = try scheduledItem()
        source.startDate = try canonical(2026, 10, startDay)
        source.endDate = try endDay.map { try canonical(2026, 10, $0) }
        source.autoRenew = endDay == nil
        let result = try GetAnalyticsCurrentObligations(repository: ForecastRepository([source]))
            .execute(today: civil(2026, 10, 21))
        #expect(result.map(\.id) == (included ? [source.id] : []))
    }

    @Test("Archived timestamps exclude otherwise active obligations")
    func currentObligationArchive() throws {
        var source = try scheduledItem()
        source.archivedAt = try canonical(2026, 10, 20)
        let result = try GetAnalyticsCurrentObligations(repository: ForecastRepository([source]))
            .execute(today: civil(2026, 10, 21))
        #expect(result.isEmpty)
    }

    @Test("Current-obligation repository failures remain errors")
    func currentObligationReadFailure() throws {
        let repository = ForecastRepository([])
        repository.readError = .unavailable
        do {
            _ = try GetAnalyticsCurrentObligations(repository: repository).execute(today: civil())
            Issue.record("Expected the repository error")
        } catch RateProviderError.unavailable {
            #expect(repository.allReads == 1)
        }
    }

    @Test("Current obligations reject noncanonical billing-day inputs")
    func currentObligationInvalidDate() throws {
        var source = try scheduledItem()
        source.startDate = source.startDate.addingTimeInterval(3_600)
        #expect(throws: BillingCivilDayError.nonCanonicalDate(source.startDate)) {
            try GetAnalyticsCurrentObligations(repository: ForecastRepository([source])).execute(today: civil())
        }
    }

    @Test("Included count localizes text and regional numeric formatting", arguments: ["ru_RU", "en_US"])
    func includedCountLocalization(localeID: String) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let sources = try (0..<1_234).map { _ in try scheduledItem() }
        let vm = try scheduledViewModel(ForecastRepository(sources), preferences: fixture.repository)
        vm.load()
        let locale = Locale(identifier: localeID)
        let language = localeID == "ru_RU" ? "ru" : "en"
        let url = try #require(Bundle.main.url(forResource: language, withExtension: "lproj"))
        let bundle = try #require(Bundle(url: url))
        let number = 1_234.formatted(.number.locale(locale))
        #expect(vm.screenState.includedItemCount == 1_234)
        #expect(vm.screenState.includedCountLabel(locale: locale, bundle: bundle) ==
            (localeID == "ru_RU" ? "Учтено: \(number)" : "Included: \(number)"))
    }

    private func annualItem(_ id: UInt8 = 1, anchor: CivilDate,
                            status: ItemStatus = .active, amount: Decimal = 1_200) throws -> RecurringItem {
        let date = try BillingCivilDay.canonicalDate(for: anchor)
        return RecurringItem(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, id)),
            title: "Annual", amount: amount, currencyCode: "RUB", billingCycle: .annual,
            startDate: try canonical(2020, 1, 1), nextChargeDate: date, status: status)
    }

    @Test("Annual rows use the nearest canonical anniversary", arguments: [
        (2025, 10, 15, 2026, 10, 21, 2027, 10, 15),
        (2026, 11, 15, 2026, 10, 21, 2026, 11, 15),
        (2026, 10, 21, 2026, 10, 21, 2026, 10, 21),
        (2024, 2, 29, 2027, 3, 1, 2028, 2, 29),
        (2040, 11, 15, 2026, 10, 21, 2026, 11, 15)
    ])
    func annualCanonicalDates(_ ay: Int, _ am: Int, _ ad: Int, _ ty: Int, _ tm: Int, _ td: Int,
                              _ ey: Int, _ em: Int, _ ed: Int) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let source = try annualItem(anchor: civil(ay, am, ad))
        let vm = try scheduledViewModel(ForecastRepository([source]), preferences: fixture.repository,
                                         today: civil(ty, tm, td))
        vm.load()
        let row = try #require(vm.screenState.annualItems.first)
        #expect(row.chargeState == .found(try civil(ey, em, ed)))
        #expect(row.projectionError == nil)
        #expect(row.item.nextChargeDate == source.nextChargeDate)
        #expect(row.subtitle.contains("Просрочено") == false)
        if ty == ey && tm == em && td == ed { #expect(row.subtitle == String(localized: "Сегодня")) }
    }

    @Test("Annual finite bounds are inclusive and absence stays visible", arguments: [14, 15])
    func annualFiniteResult(endDay: Int) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        var source = try annualItem(anchor: civil(2025, 11, 15))
        source.autoRenew = false
        source.endDate = try canonical(2026, 11, endDay)
        let vm = try scheduledViewModel(ForecastRepository([source]), preferences: fixture.repository)
        vm.load()
        let row = try #require(vm.screenState.annualItems.first)
        #expect(row.chargeState == (endDay == 15 ? .found(try civil(2026, 11, 15)) : .absent))
        #expect(row.projectionError == nil)
        if endDay == 14 { #expect(row.subtitle == String(localized: "analytics.annual.notScheduled")) }
    }

    @Test("Trial stays outside normalized annual rows while forecast retains its semantics", arguments: [true, false])
    func annualTrialResult(provenCharge: Bool) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        var source = try annualItem(anchor: civil(2026, 11, 15), status: .trial)
        source.startDate = try canonical(2026, 10, 1)
        source.trialEndDate = try canonical(2026, 11, provenCharge ? 15 : 14)
        let vm = try scheduledViewModel(ForecastRepository([source]), preferences: fixture.repository)
        vm.load()
        #expect(vm.screenState.annualItems.isEmpty)
        #expect(vm.screenState.includedItemCount == 0)
        #expect(vm.screenState.monthlyAggregation?.total?.amount == 0)
        if provenCharge {
            #expect(vm.screenState.forecastMonths[1].schedule.eventCount == 2)
            #expect(vm.screenState.forecastMonths[1].schedule.charges.count == 1)
        } else {
            #expect(vm.screenState.forecastMonths[1].schedule.monetaryCompleteness == .unavailable)
            #expect(vm.screenState.forecastMonths[1].schedule.charges.isEmpty)
            #expect(vm.screenState.forecastMonths[1].schedule.eventCount == 1)
        }
    }

    @Test("Annual rows sort by projected dates then error and absence with UUID ties")
    func annualProjectedOrdering() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let september = try annualItem(3, anchor: civil(2020, 9, 1))
        let november2 = try annualItem(2, anchor: civil(2026, 11, 15))
        let november1 = try annualItem(1, anchor: civil(2026, 11, 15))
        var error2 = try annualItem(5, anchor: civil(2026, 11, 15))
        error2.autoRenew = false
        var error1 = try annualItem(4, anchor: civil(2026, 11, 15))
        error1.autoRenew = false
        var absent2 = try annualItem(7, anchor: civil(2025, 11, 15))
        absent2.endDate = try canonical(2026, 10, 31)
        var absent1 = try annualItem(6, anchor: civil(2025, 11, 15))
        absent1.endDate = try canonical(2026, 10, 31)
        let vm = try scheduledViewModel(ForecastRepository([absent2, error2, september, november2,
                                                            absent1, november1, error1]), preferences: fixture.repository)
        vm.load()
        #expect(vm.screenState.annualItems.map(\.id) == [november1, november2, september, error1, error2, absent1, absent2].map(\.id))
        #expect(vm.screenState.annualItems.map(\.chargeState) == [
            .found(try civil(2026, 11, 15)), .found(try civil(2026, 11, 15)), .found(try civil(2027, 9, 1)),
            .unavailable, .unavailable, .absent, .absent
        ])
    }

    @Test("Normalized sections share current non-trial membership and leave forecast intact")
    func annualMembershipAndOtherSections() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        var sources = try ItemStatus.allCases.enumerated().map { index, status in
            try annualItem(UInt8(index + 1), anchor: civil(2026, 11, 15), status: status)
        }
        let active = sources.filter { [.active, .dueSoon, .dueToday, .overdue, .failed].contains($0.status) }
        for index in sources.indices {
            sources[index].usageStatus = .unused
            sources[index].category = .music
        }
        let monthly = try scheduledItem()
        sources.append(monthly)
        let repository = ForecastRepository(sources)
        let vm = try scheduledViewModel(repository, preferences: fixture.repository)
        vm.load()
        #expect(Set(vm.screenState.annualItems.map(\.id)) == Set(active.map(\.id)))
        #expect(repository.activeReads == 0)
        #expect(repository.allReads == 2)
        #expect(vm.screenState.summary.activeItemCount == active.count + 1)
        #expect(vm.screenState.summary.monthlyTotal == active.reduce(Decimal(100)) { $0 + $1.monthlyEquivalent })
        #expect(vm.screenState.includedItemCount == active.count + 1)
        #expect(vm.screenState.topItems.count == 5)
        #expect(Set(vm.screenState.topItems.map(\.id)).isSubset(of: Set((active + [monthly]).map(\.id))))
        #expect(Set(vm.screenState.unusedItems.map(\.id)) == Set(active.map(\.id)))
        #expect(vm.screenState.categoryBreakdown.first { $0.category == .music }?.itemCount == active.count)
        #expect(vm.screenState.unusedMonthlyCost == active.reduce(Decimal.zero) { $0 + $1.monthlyEquivalent })
        let expected = try forecast(sources, today: civil(2026, 10, 21))
        #expect(vm.screenState.forecastMonths.map(\.schedule) == expected)
    }

    @Test("Annual civil dates and countdowns are timezone stable", arguments: ["Pacific/Kiritimati", "America/Los_Angeles"])
    func annualTimezoneStability(zoneID: String) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let source = try annualItem(anchor: civil(2025, 11, 15))
        let zone = try #require(TimeZone(identifier: zoneID))
        let vm = try scheduledViewModel(ForecastRepository([source]), preferences: fixture.repository, zone: zone)
        vm.load()
        let row = try #require(vm.screenState.annualItems.first)
        #expect(row.chargeState == .found(try civil(2026, 11, 15)))
        #expect(vm.screenState.includedItemCount == 1)
        #expect(vm.screenState.monthlyAggregation?.total?.amount == source.monthlyEquivalent)
        let formatter = PresentationLocale.dateFormatter(template: "d MMMM", calendar: BillingCivilDay.calendar)
        formatter.timeZone = .gmt
        let dateText = formatter.string(from: try canonical(2026, 11, 15))
        #expect(row.subtitle == String(localized: "Через \(25) дн. — \(dateText)"))
    }

    private final class ForecastRepository: RecurringItemRepository {
        var items: [RecurringItem]
        var allReads = 0
        var activeReads = 0
        var readError: RateProviderError?
        init(_ items: [RecurringItem]) { self.items = items }
        func fetchAll() throws -> [RecurringItem] {
            allReads += 1
            if let readError { throw readError }
            return items
        }
        func fetchActive() throws -> [RecurringItem] {
            activeReads += 1
            return items.filter {
                [.active, .dueSoon, .dueToday, .trial].contains($0.status) && $0.archivedAt == nil
            }
        }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { [] }
        func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
        func save(_ item: RecurringItem) throws {}
        func update(_ item: RecurringItem) throws {}
        func delete(id: UUID) throws {}
        func saveAll(_ items: [RecurringItem]) throws {}
        func deleteAll() throws {}
    }

    private func civil(_ year: Int = 2026, _ month: Int = 10, _ day: Int = 1) throws -> CivilDate {
        try CivilDate(year: year, month: month, day: day)
    }

    private func canonical(_ year: Int = 2026, _ month: Int = 10, _ day: Int = 1) throws -> Date {
        try BillingCivilDay.canonicalDate(for: civil(year, month, day))
    }

    private func scheduledItem(cycle: BillingCycle = .monthly, amount: Decimal = 100,
                               status: ItemStatus = .active, currency: String = "RUB") throws -> RecurringItem {
        RecurringItem(title: "Schedule", amount: amount, currencyCode: currency, billingCycle: cycle,
                      startDate: try canonical(), nextChargeDate: try canonical(2026, 10, 15), status: status)
    }

    private func forecast(_ items: [RecurringItem], today: CivilDate? = nil) throws -> [AnalyticsForecastMonth] {
        try GetAnalyticsForecast(repository: ForecastRepository(items)).execute(today: today ?? civil())
    }

    private func chargeDates(_ months: [AnalyticsForecastMonth]) throws -> [CivilDate] {
        try months.flatMap(\.charges).map { try BillingCivilDay.civilDate(fromCanonicalDate: $0.date) }
    }

    private func scheduledViewModel(_ repository: ForecastRepository, preferences: UserPreferencesRepository,
                                    today: CivilDate? = nil, zone: TimeZone = .gmt,
                                    provider: any ExchangeRateProvider = StaticExchangeRateProvider()) throws -> AnalyticsViewModel {
        let today = try today ?? civil(2026, 10, 21)
        var local = BillingCivilDay.calendar
        local.timeZone = zone
        let instant = try #require(local.date(from: DateComponents(
            year: today.year, month: today.month, day: today.day, hour: 12
        )))
        return AnalyticsViewModel(getCurrentObligations: GetAnalyticsCurrentObligations(repository: repository),
                                  getForecast: GetAnalyticsForecast(repository: repository),
                                  preferences: preferences, exchangeRateProvider: provider,
                                  now: { instant }, timeZone: { zone })
    }

    @Test("Quarterly forecast uses monetary occurrences, not monthly equivalents")
    func quarterlyCanonicalAmounts() throws {
        let months = try forecast([scheduledItem(cycle: .quarterly, amount: 600)])
        #expect(months.map { $0.charges.reduce(Decimal.zero) { $0 + $1.amount } } == [600, 0, 0, 600, 0, 0])
        #expect(try chargeDates(months) == [civil(2026, 10, 15), civil(2027, 1, 15)])
        #expect(try months.map { try BillingCivilDay.civilDate(fromCanonicalDate: $0.range.lowerBound) }
                == [civil(2026, 10), civil(2026, 11), civil(2026, 12), civil(2027, 1), civil(2027, 2), civil(2027, 3)])
        #expect(months.last?.range.upperBound == (try canonical(2027, 4)))
    }

    @Test("Elapsed current-month days remain scheduled occurrences")
    func monthlyIncludesElapsedDays() throws {
        let months = try forecast([scheduledItem()], today: civil(2026, 10, 21))
        #expect(try chargeDates(months) == (10...15).map {
            try civil($0 <= 12 ? 2026 : 2027, $0 <= 12 ? $0 : $0 - 12, 15)
        })
        #expect(months.allSatisfy { $0.charges.map(\.amount) == [100] })
    }

    @Test("Weekly forecast preserves every monetary occurrence")
    func weeklyCountsEveryCharge() throws {
        var item = try scheduledItem(cycle: .weekly)
        item.nextChargeDate = try canonical()
        let months = try forecast([item])
        #expect(months.map { $0.charges.count } == [5, 4, 5, 4, 4, 4])
        #expect(try chargeDates([months[0]]) == [1, 8, 15, 22, 29].map { try civil(2026, 10, $0) })
        #expect(months[0].charges.reduce(Decimal.zero) { $0 + $1.amount } == 500)
    }

    @Test("Annual forecast contains the full charge only in its occurrence month")
    func annualFullOccurrence() throws {
        var item = try scheduledItem(cycle: .annual, amount: 1_200)
        item.nextChargeDate = try canonical(2026, 12, 15)
        let months = try forecast([item])
        #expect(months.map { $0.charges.reduce(Decimal.zero) { $0 + $1.amount } } == [0, 0, 1_200, 0, 0, 0])
        #expect(try chargeDates(months) == [civil(2026, 12, 15)])
    }

    @Test("Month-end forecast retains the original January 31 anchor")
    func monthEndRecovery() throws {
        var item = try scheduledItem()
        item.startDate = try canonical(2026, 1)
        item.nextChargeDate = try canonical(2026, 1, 31)
        let months = try forecast([item], today: civil(2026, 1, 20))
        #expect(try chargeDates(months) == [civil(2026, 1, 31), civil(2026, 2, 28), civil(2026, 3, 31),
                                            civil(2026, 4, 30), civil(2026, 5, 31), civil(2026, 6, 30)])
    }

    @Test("Leap-day annual forecast recovers the original leap day", arguments: [2027, 2028])
    func leapDayRecovery(year: Int) throws {
        var item = try scheduledItem(cycle: .annual)
        item.startDate = try canonical(2024, 2)
        item.nextChargeDate = try canonical(2024, 2, 29)
        #expect(try chargeDates(forecast([item], today: civil(year, 2))) == [civil(year, 2, year == 2028 ? 29 : 28)])
    }

    @Test("Same-day occurrences from separate items are never collapsed")
    func sameDayChargesRemainSeparate() throws {
        let first = try scheduledItem(amount: 100)
        let second = try scheduledItem(amount: 250)
        let months = try forecast([first, second])
        #expect(months.allSatisfy { $0.charges.count == 2 && $0.charges.reduce(Decimal.zero) { $0 + $1.amount } == 350 })
    }

    @Test("Forecast lifecycle eligibility follows the projector", arguments: ItemStatus.allCases.filter { $0 != .trial })
    func canonicalLifecycle(status: ItemStatus) throws {
        let item = try scheduledItem(status: status)
        let months = try forecast([item])
        let included = [.active, .dueSoon, .dueToday, .overdue, .failed].contains(status)
        #expect(months.flatMap(\.charges).count == (included ? 6 : 0))
        #expect(months.allSatisfy { $0.monetaryCompleteness == .complete })
    }

    @Test("Trial boundary is not an extra monetary charge")
    func trialBoundaryDistinctFromCharge() throws {
        var item = try scheduledItem(status: .trial)
        item.trialEndDate = item.nextChargeDate
        let months = try forecast([item])
        #expect(months[0].eventCount == 2)
        #expect(months[0].charges.count == 1)
        #expect(months[0].charges.first?.amount == 100)
        item.nextChargeDate = try canonical(2026, 10, 16)
        let unknown = try forecast([item])
        #expect(unknown[0].eventCount == 1)
        #expect(unknown.flatMap(\.charges).isEmpty)
        #expect(unknown.allSatisfy { $0.monetaryCompleteness == .unavailable })
    }

    @Test("Finite bounds include start and end, but not later occurrences")
    func finiteBoundsInclusive() throws {
        var item = try scheduledItem()
        item.startDate = try canonical(2026, 11, 15)
        item.autoRenew = false
        item.endDate = try canonical(2026, 12, 15)
        #expect(try chargeDates(forecast([item])) == [civil(2026, 11, 15), civil(2026, 12, 15)])
        #expect(try forecast([item], today: civil(2027, 1)).flatMap(\.charges).isEmpty)
    }

    @Test("Six-month boundary is stable in positive and negative local timezones",
          arguments: ["Pacific/Kiritimati", "America/Los_Angeles"])
    func forecastCivilTimezoneStability(zoneID: String) throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let zone = try #require(TimeZone(identifier: zoneID))
        let vm = try scheduledViewModel(ForecastRepository([scheduledItem()]), preferences: fixture.repository,
                                         today: civil(2026, 10, 1), zone: zone)
        vm.load()
        #expect(vm.error == nil)
        #expect(vm.screenState.monthlyProjections.map(\.month) == (try forecast([scheduledItem()]).map { $0.range.lowerBound }))
        #expect(vm.screenState.monthlyProjections.map(\.total) == [100, 100, 100, 100, 100, 100])
    }

    @Test("Forecast and current-obligation snapshots each fetch once and retain their calculations")
    func forecastPopulationAndSummaryRemainIndependent() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let repository = try ForecastRepository([scheduledItem(cycle: .quarterly, amount: 600),
                                                 scheduledItem(status: .overdue), scheduledItem(status: .failed)])
        let vm = try scheduledViewModel(repository, preferences: fixture.repository)
        vm.load()
        #expect(repository.allReads == 2)
        #expect(repository.activeReads == 0)
        #expect(vm.screenState.includedItemCount == 3)
        let expected = repository.items.reduce(Decimal.zero) { $0 + $1.monthlyEquivalent }
        #expect(vm.screenState.monthlyAggregation?.total?.amount == expected)
        #expect(vm.screenState.summary.yearlyProjection == expected * 12)
        #expect(vm.screenState.topItems.count == 3)
        #expect(vm.screenState.monthlyProjections.map(\.total) == [800, 200, 200, 800, 200, 200])
        let originalAnchor = repository.items[0].nextChargeDate
        await refresh(vm)
        #expect(repository.allReads == 2)
        #expect(repository.items[0].nextChargeDate == originalAnchor)
        repository.items.removeLast()
        vm.load(forceReload: true)
        #expect(repository.allReads == 4)
        #expect(vm.screenState.monthlyProjections[0].total == 700)
    }

    @Test("Forecast-only foreign charges request FX and retain incomplete results")
    func forecastOnlyCurrenciesAndMissingRates() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        var trial = try scheduledItem(status: .trial, currency: "GBP")
        trial.trialEndDate = trial.nextChargeDate
        let repository = ForecastRepository([trial])
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
        let vm = try scheduledViewModel(repository, preferences: fixture.repository, provider: provider)
        vm.load()
        await refresh(vm)
        #expect(await provider.requests() == 1)
        #expect(repository.allReads == 2)
        #expect(vm.screenState.summary.activeItemCount == 0)
        #expect(vm.screenState.isEmpty == false)
        #expect(vm.screenState.monthlyProjections.isEmpty)
        #expect(vm.screenState.forecastMonths.count == 6)
        #expect(vm.screenState.forecastMonths.allSatisfy {
            $0.aggregation.total == nil && $0.aggregation.missingCurrencyCodes == ["GBP"] && $0.completeTotal == nil
        })
    }

    @Test("Partial forecast is retained distinctly from a complete total")
    func partialForecastRetainsKnownMoney() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let repository = try ForecastRepository([scheduledItem(), scheduledItem(currency: "GBP")])
        let vm = try scheduledViewModel(repository, preferences: fixture.repository)
        vm.load()
        #expect(vm.screenState.monthlyProjections.isEmpty)
        #expect(vm.screenState.forecastMonths.allSatisfy {
            $0.aggregation.isComplete == false && $0.aggregation.total?.amount == 100
                && $0.aggregation.missingCurrencyCodes == ["GBP"] && $0.completeTotal == nil
        })
    }

    @Test("Unknown trial money never becomes a complete zero forecast")
    func unavailableScheduleIsNotZero() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        var item = try scheduledItem(status: .trial)
        item.trialEndDate = try canonical(2026, 10, 14)
        let vm = try scheduledViewModel(ForecastRepository([item]), preferences: fixture.repository)
        vm.load()
        #expect(vm.screenState.forecastMonths.count == 6)
        #expect(vm.screenState.forecastMonths.allSatisfy { $0.completeTotal == nil })
        #expect(vm.screenState.monthlyProjections.isEmpty)
    }

    @Test("Repository failure is surfaced rather than replaced with an empty forecast")
    func forecastReadFailurePropagates() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let repository = ForecastRepository([])
        repository.readError = .unavailable
        let vm = try scheduledViewModel(repository, preferences: fixture.repository)
        vm.load()
        #expect(vm.error != nil)
        #expect(vm.isLoaded == false)
    }

    @Test("Cancelled FX response cannot complete the forecast")
    func cancelledForecastFXIsIgnored() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = ControlledExchangeRateProvider()
        let repository = try ForecastRepository([scheduledItem(status: .failed, currency: "USD")])
        let vm = try scheduledViewModel(repository, preferences: fixture.repository, provider: provider)
        vm.load()
        let revision = vm.aggregationRevision
        let task = Task { await vm.refreshCurrencyAggregation(revision: revision) }
        await provider.waitForRequests(1)
        task.cancel()
        await provider.succeedRequest(at: 0, with: snapshot())
        await task.value
        #expect(vm.screenState.monthlyProjections.isEmpty)
        #expect(vm.screenState.forecastMonths.allSatisfy { $0.aggregation.isComplete == false })
        #expect(repository.allReads == 2)
    }
}
