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
            nextChargeDate: nextChargeDate,
            usageStatus: usageStatus
        )
    }

    private func viewModel(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: any ExchangeRateProvider
    ) -> AnalyticsViewModel {
        AnalyticsViewModel(
            getActiveItems: GetActiveItems(
                repository: InMemoryRecurringItemRepository(items: items)
            ),
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
        let provider = RecordingExchangeRateProvider(responses: [.success(snapshot())])
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

        guard case let .partial(total, codes, _) = vm.screenState.monthlyAggregation else {
            Issue.record("Expected partial Analytics aggregation")
            return
        }
        #expect(total.amount == 500)
        #expect(codes == ["EUR", "GBP"])
    }

    @Test("Foreign-only unavailable data is not represented as zero")
    func unavailableIsNotZero() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.failure(.unavailable)])
        let vm = viewModel(
            items: [item(title: "USD", amount: 10, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case .unavailable = vm.screenState.monthlyAggregation else {
            Issue.record("Expected unavailable Analytics aggregation")
            return
        }
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
