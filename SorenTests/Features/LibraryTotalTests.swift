import Foundation
import Observation
import Testing
@testable import Soren

@Suite("Library currency aggregation")
@MainActor
struct LibraryTotalTests {
    @MainActor
    private final class InMemoryRecurringItemRepository: RecurringItemRepository {
        private var items: [RecurringItem]

        init(items: [RecurringItem]) {
            self.items = items
        }

        func fetchAll() throws -> [RecurringItem] { items }
        func fetchActive() throws -> [RecurringItem] { items.filter { $0.status.countsInTotals } }
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
            case let .success(snapshot):
                return snapshot
            case let .failure(error):
                throw error
            }
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
        let suiteName = "LibraryTotalTests.\(UUID().uuidString)"
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
        rubRate: Decimal = 80,
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
        status: ItemStatus = .active
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: cycle,
            nextChargeDate: .now,
            status: status
        )
    }

    private func viewModel(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: RecordingExchangeRateProvider,
        searchDebounceDelay: Duration = .zero
    ) -> LibraryViewModel {
        let repository = InMemoryRecurringItemRepository(items: items)
        return LibraryViewModel(
            getLibraryItems: GetLibraryItems(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            preferences: preferences,
            exchangeRateProvider: provider,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            searchDebounceDelay: searchDebounceDelay
        )
    }

    private func refresh(_ viewModel: LibraryViewModel) async {
        await viewModel.refreshCurrencyAggregation(revision: viewModel.aggregationRevision)
    }

    private func waitForFilteredItemsChange(
        in viewModel: LibraryViewModel,
        action: () -> Void
    ) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = viewModel.filteredItems
            } onChange: {
                continuation.resume()
            }
            action()
        }
    }

    @Test("Mixed currencies are converted before the current filtered subtotal")
    func mixedCurrenciesConvertBeforeAggregation() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let usd = try decimal("12.99")
        let rubRate = try decimal("76.76")
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: rubRate))
        ])
        let vm = viewModel(
            items: [
                item(title: "IVI", amount: 299, currencyCode: "RUB"),
                item(title: "Apple TV+", amount: usd, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        guard case let .partial(initialTotal, missingCodes, _) = vm.filteredMonthlyAggregation else {
            Issue.record("Expected truthful partial subtotal before the snapshot arrives")
            return
        }
        #expect(initialTotal.amount == 299)
        #expect(missingCodes == ["USD"])

        await refresh(vm)

        #expect(vm.filteredMonthlyAggregation?.total?.amount == Decimal(299) + usd * rubRate)
        #expect(vm.filteredMonthlyAggregation?.total?.currencyCode == "RUB")
        #expect(vm.filteredMonthlyAggregation?.isComplete == true)
        #expect(vm.filteredItems.map(\.currencyCode) == ["RUB", "USD"])
    }

    @Test("Unavailable rates never create a raw mixed-currency total")
    func unavailableRatesNeverCreateRawMixedTotal() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.failure(.unavailable)])
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

        guard case let .partial(total, missingCodes, _) = vm.filteredMonthlyAggregation else {
            Issue.record("Expected partial subtotal when only the foreign rate is unavailable")
            return
        }
        #expect(total.amount == 500)
        #expect(total.amount != 510)
        #expect(missingCodes == ["USD"])
    }

    @Test("Foreign-only subtotal is unavailable rather than a fake zero")
    func foreignOnlySubtotalIsUnavailable() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [.failure(.unavailable)])
        let vm = viewModel(
            items: [item(title: "Spotify", amount: 12, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case let .unavailable(reportingCode, missingCodes, reason, _) = vm.filteredMonthlyAggregation else {
            Issue.record("Expected unavailable state without a convertible amount")
            return
        }
        #expect(reportingCode == "RUB")
        #expect(missingCodes == ["USD"])
        #expect(reason == .noConvertibleAmounts)
        #expect(vm.filteredMonthlyAggregation?.total == nil)
    }

    @Test("Same-currency subtotal does not request exchange rates")
    func sameCurrencySubtotalDoesNotRequestRates() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(title: "IVI", amount: 299, currencyCode: "RUB"),
                item(title: "KION", amount: 199, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.filteredMonthlyAggregation?.total?.amount == 498)
        #expect(await provider.requests() == 0)
    }

    @Test("Annual subscriptions retain monthly normalization before conversion")
    func annualSubscriptionUsesMonthlyNormalization() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [item(title: "Annual", amount: 1_200, currencyCode: "RUB", cycle: .annual)],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()

        #expect(vm.filteredMonthlyAggregation?.total?.amount == Decimal(1_200) * BillingCycle.annual.monthlyMultiplier)
    }

    @Test("Existing status contract excludes cancelled paused and archived items")
    func existingStatusContractIsPreserved() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(title: "Active", amount: 300, currencyCode: "RUB"),
                item(title: "Trial", amount: 200, currencyCode: "RUB", status: .trial),
                item(title: "Cancelled", amount: 900, currencyCode: "RUB", status: .cancelled),
                item(title: "Paused", amount: 800, currencyCode: "RUB", status: .paused),
                item(title: "Archived", amount: 700, currencyCode: "RUB", status: .archived)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()

        #expect(vm.filteredMonthlyAggregation?.total?.amount == 500)
    }

    @Test("Search subtotal follows existing filtered-result semantics without another request")
    func searchSubtotalUsesCurrentResultAndReusesSnapshot() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let rubRate = try decimal("80")
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: rubRate))
        ])
        let vm = viewModel(
            items: [
                item(title: "Spotify", amount: 10, currencyCode: "USD"),
                item(title: "IVI", amount: 299, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider,
            searchDebounceDelay: .milliseconds(10)
        )

        vm.load()
        await refresh(vm)
        let loadedRevision = vm.aggregationRevision
        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "IVI"
            vm.searchText = "Spot"
            vm.searchText = "Spotify"
        }

        #expect(vm.searchText == "Spotify")
        #expect(vm.filteredItems.map(\.title) == ["Spotify"])
        #expect(vm.filteredMonthlyAggregation?.total?.amount == Decimal(10) * rubRate)
        #expect(vm.aggregationRevision == loadedRevision)
        await refresh(vm)
        #expect(await provider.requests() == 1)
    }

    @Test("One successful snapshot is shared by the current Library revision")
    func successfulSnapshotIsLoadedOncePerRevision() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot())
        ])
        let vm = viewModel(
            items: [item(title: "Spotify", amount: 10, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)
        await refresh(vm)

        #expect(await provider.requests() == 1)
    }

    @Test("Stale cached snapshots remain visible with stale metadata")
    func staleSnapshotIsRepresentedAsStale() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let age: TimeInterval = 7 * 3_600
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: age)))
        ])
        let vm = viewModel(
            items: [item(title: "Spotify", amount: 10, currencyCode: "USD")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        #expect(vm.filteredMonthlyAggregation?.rateMetadata?.freshness == .stale(age: age))
    }
}
