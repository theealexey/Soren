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
        private var remainingDeleteFailures: Int

        init(items: [RecurringItem], deleteFailures: Int = 0) {
            self.items = items
            self.remainingDeleteFailures = deleteFailures
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
        func delete(id: UUID) throws {
            if remainingDeleteFailures > 0 {
                remainingDeleteFailures -= 1
                throw DeleteFailure.rejected
            }
            items.removeAll { $0.id == id }
        }
        func saveAll(_ items: [RecurringItem]) throws { self.items.append(contentsOf: items) }
        func deleteAll() throws { items.removeAll() }
    }

    private enum DeleteFailure: Error {
        case rejected
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

    private actor DeferredExchangeRateProvider: ExchangeRateProvider {
        private var continuations: [CheckedContinuation<ExchangeRateSnapshot, Error>] = []
        private var requestCount = 0
        private var requestWaiters: [CheckedContinuation<Void, Never>] = []

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            let waiters = requestWaiters
            requestWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }

            return try await withCheckedThrowingContinuation { continuation in
                continuations.append(continuation)
            }
        }

        func waitForRequests(_ expectedCount: Int) async {
            guard requestCount < expectedCount else { return }
            await withCheckedContinuation { continuation in
                requestWaiters.append(continuation)
            }
        }

        func resumeRequest(at index: Int, with snapshot: ExchangeRateSnapshot) {
            guard continuations.indices.contains(index) else { return }
            continuations.remove(at: index).resume(returning: snapshot)
        }
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
        id: UUID = UUID(),
        title: String,
        amount: Decimal,
        currencyCode: String,
        cycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        startDate: Date = .now,
        nextChargeDate: Date = .now,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        createdAt: Date = .now,
        archivedAt: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            id: id,
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: cycle,
            startDate: BillingCivilDay.calendar.startOfDay(for: startDate),
            nextChargeDate: BillingCivilDay.calendar.startOfDay(for: nextChargeDate),
            autoRenew: autoRenew,
            endDate: endDate.map { BillingCivilDay.calendar.startOfDay(for: $0) },
            status: status,
            createdAt: createdAt,
            archivedAt: archivedAt
        )
    }

    private func viewModel<Provider: ExchangeRateProvider>(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: Provider,
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

    @Test("Expired finite items do not contribute to the current Library subtotal")
    func expiredFiniteItemIsExcludedFromCurrentSubtotal() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let calendar = Calendar(identifier: .gregorian)
        let endDate = try #require(calendar.date(byAdding: .day, value: -1, to: .now))
        let startDate = try #require(calendar.date(byAdding: .month, value: -1, to: endDate))
        let vm = viewModel(
            items: [
                item(title: "Current", amount: 100, currencyCode: "RUB"),
                item(
                    title: "Expired finite",
                    amount: 900,
                    currencyCode: "RUB",
                    startDate: startDate,
                    nextChargeDate: endDate,
                    autoRenew: false,
                    endDate: endDate
                )
            ],
            preferences: fixture.repository,
            provider: RecordingExchangeRateProvider(responses: [])
        )

        vm.load()

        #expect(vm.filteredMonthlyAggregation?.total?.amount == 100)
    }

    @Test("Default sections distinguish current completed and archived records truthfully")
    func defaultSectionsUseCurrentSemantics() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let calendar = Calendar(identifier: .gregorian)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: .now))
        let monthAgo = try #require(calendar.date(byAdding: .month, value: -1, to: yesterday))
        let currentItems = [
            item(title: "Active", amount: 100, currencyCode: "RUB"),
            item(title: "Paused", amount: 100, currencyCode: "RUB", status: .paused),
            item(title: "Cancelled", amount: 100, currencyCode: "RUB", status: .cancelled),
            item(title: "Trial", amount: 100, currencyCode: "RUB", status: .trial),
            item(title: "Failed", amount: 100, currencyCode: "RUB", status: .failed)
        ]
        let completed = item(
            title: "Completed",
            amount: 100,
            currencyCode: "RUB",
            startDate: monthAgo,
            nextChargeDate: yesterday,
            autoRenew: false,
            endDate: yesterday
        )
        let archived = item(
            title: "Archived",
            amount: 100,
            currencyCode: "RUB",
            status: .archived,
            archivedAt: yesterday
        )
        let vm = viewModel(
            items: currentItems + [completed, archived],
            preferences: fixture.repository,
            provider: RecordingExchangeRateProvider(responses: [])
        )

        vm.load()

        #expect(vm.sections.map(\.id) == ["current", "past", "archived"])
        #expect(vm.sections[0].title == String(localized: "Текущие"))
        #expect(Set(vm.sections[0].items.map(\.title)) == Set(currentItems.map(\.title)))
        #expect(vm.sections[1].items.map(\.title) == ["Completed"])
        #expect(vm.sections[2].items.map(\.title) == ["Archived"])
    }

    @Test("Delete failure remains observable and a retry can succeed")
    func deleteFailurePersistsUntilRetry() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let target = item(title: "Spotify", amount: 199, currencyCode: "RUB")
        let repository = InMemoryRecurringItemRepository(items: [target], deleteFailures: 1)
        let vm = LibraryViewModel(
            getLibraryItems: GetLibraryItems(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            preferences: fixture.repository,
            exchangeRateProvider: RecordingExchangeRateProvider(responses: []),
            searchDebounceDelay: .zero
        )
        vm.load()

        #expect(await vm.deleteItem(target) == false)

        #expect(vm.error != nil)
        #expect(vm.failedAction == .delete(itemID: target.id))
        #expect(vm.allItems.map(\.id) == [target.id])

        vm.dismissError()

        #expect(vm.error == nil)
        #expect(vm.failedAction == nil)
        #expect(vm.allItems.map(\.id) == [target.id])

        #expect(await vm.deleteItem(target) == true)

        #expect(vm.error == nil)
        #expect(vm.failedAction == nil)
        #expect(vm.allItems.isEmpty)
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
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB"),
                item(title: "USD", amount: 2, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc

        vm.load()
        await refresh(vm)

        #expect(vm.filteredMonthlyAggregation?.rateMetadata?.freshness == .stale(age: age))
        #expect(vm.filteredItems.map(\.title) == ["RUB", "USD"])
    }

    @Test("A stale snapshot without a successful foreign subtotal has no Library stale metadata")
    func staleSnapshotWithoutSuccessfulForeignConversionHasNoMetadata() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let age: TimeInterval = 7 * 3_600
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: age)))
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB"),
                item(title: "GBP", amount: 2, currencyCode: "GBP")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case let .partial(total, missingCodes, metadata) = vm.filteredMonthlyAggregation else {
            Issue.record("Expected a partial Library subtotal")
            return
        }
        #expect(total.amount == 100)
        #expect(missingCodes == ["GBP"])
        #expect(metadata == nil)
    }

    @Test("A stale snapshot without a convertible foreign Library amount remains unavailable")
    func staleSnapshotWithoutConvertibleForeignAmountIsUnavailable() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(freshness: .stale(age: 7 * 3_600)))
        ])
        let vm = viewModel(
            items: [item(title: "GBP", amount: 2, currencyCode: "GBP")],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        await refresh(vm)

        guard case let .unavailable(_, missingCodes, _, metadata) = vm.filteredMonthlyAggregation else {
            Issue.record("Expected an unavailable Library aggregation")
            return
        }
        #expect(missingCodes == ["GBP"])
        #expect(metadata == nil)
        #expect(vm.filteredMonthlyAggregation?.total == nil)
    }

    @Test("Amount sorting compares monthly reporting values instead of raw cross-currency decimals")
    func amountSortingUsesConvertedMonthlyValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let rub = item(title: "100 RUB", amount: 100, currencyCode: "RUB")
        let usd = item(title: "2 USD", amount: 2, currencyCode: "USD")
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 100))
        ])
        let vm = viewModel(
            items: [rub, usd],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc
        vm.load()
        await refresh(vm)

        #expect(vm.filteredItems.map(\.title) == ["100 RUB", "2 USD"])
        let totalBeforeDescending = vm.filteredMonthlyAggregation?.total

        vm.sortOrder = .amountDesc

        #expect(vm.filteredItems.map(\.title) == ["2 USD", "100 RUB"])
        #expect(vm.filteredMonthlyAggregation?.total == totalBeforeDescending)
        #expect(rub.amount == 100)
        #expect(rub.currencyCode == "RUB")
        #expect(usd.amount == 2)
        #expect(usd.currencyCode == "USD")
        #expect(await provider.requests() == 1)
    }

    @Test("Same-currency amount sorting does not request exchange rates")
    func sameCurrencyAmountSortingDoesNotRequestRates() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(title: "More", amount: 200, currencyCode: "RUB"),
                item(title: "Less", amount: 100, currencyCode: "RUB")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc
        vm.load()
        await refresh(vm)

        #expect(vm.filteredItems.map(\.title) == ["Less", "More"])
        #expect(await provider.requests() == 0)
    }

    @Test("Existing date, name, and recently-added sort modes remain unchanged")
    func nonAmountSortModesRemainUnchanged() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let referenceDate = Date.now
        let vm = viewModel(
            items: [
                item(
                    title: "Alpha",
                    amount: 100,
                    currencyCode: "RUB",
                    nextChargeDate: referenceDate.addingTimeInterval(3 * 86_400),
                    createdAt: referenceDate.addingTimeInterval(86_400)
                ),
                item(
                    title: "Bravo",
                    amount: 200,
                    currencyCode: "RUB",
                    nextChargeDate: referenceDate.addingTimeInterval(2 * 86_400),
                    createdAt: referenceDate.addingTimeInterval(2 * 86_400)
                ),
                item(
                    title: "Zulu",
                    amount: 300,
                    currencyCode: "RUB",
                    nextChargeDate: referenceDate.addingTimeInterval(86_400),
                    createdAt: referenceDate.addingTimeInterval(3 * 86_400)
                )
            ],
            preferences: fixture.repository,
            provider: RecordingExchangeRateProvider(responses: [])
        )

        vm.load()
        #expect(vm.filteredItems.map(\.title) == ["Zulu", "Bravo", "Alpha"])

        vm.sortOrder = .name
        #expect(vm.filteredItems.map(\.title) == ["Alpha", "Bravo", "Zulu"])

        vm.sortOrder = .recentlyAdded
        #expect(vm.filteredItems.map(\.title) == ["Zulu", "Bravo", "Alpha"])
    }

    @Test("Date sorting follows the effective next charge date shown to the user")
    func dateSortingUsesEffectiveNextChargeDate() throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let calendar = Calendar(identifier: .gregorian)
        let annualStoredDate = try #require(calendar.date(byAdding: .day, value: -20, to: .now))
        let weeklyStoredDate = try #require(calendar.date(byAdding: .day, value: -10, to: .now))
        let annual = item(
            title: "Annual",
            amount: 1_200,
            currencyCode: "RUB",
            cycle: .annual,
            nextChargeDate: annualStoredDate
        )
        let weekly = item(
            title: "Weekly",
            amount: 100,
            currencyCode: "RUB",
            cycle: .weekly,
            nextChargeDate: weeklyStoredDate
        )
        let vm = viewModel(
            items: [annual, weekly],
            preferences: fixture.repository,
            provider: RecordingExchangeRateProvider(responses: [])
        )

        vm.load()

        #expect(annual.nextChargeDate < weekly.nextChargeDate)
        let today = try BillingDatePresentation.today()
        #expect(try weekly.effectiveNextChargeDate(relativeTo: today) < annual.effectiveNextChargeDate(relativeTo: today))
        #expect(vm.filteredItems.map(\.title) == ["Weekly", "Annual"])
    }

    @Test("Amount sorting normalizes every supported billing cycle before conversion")
    func amountSortingNormalizesBillingCyclesBeforeConversion() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let normalizedCases: [(String, Decimal, BillingCycle)] = [
            ("Annual", 120, .annual),
            ("Quarterly", 30, .quarterly),
            ("Semiannual", 60, .semiannual),
            ("Weekly", 2, .weekly),
            ("Custom", 3, .custom(days: 10))
        ]

        for (title, amount, cycle) in normalizedCases {
            let provider = RecordingExchangeRateProvider(responses: [
                .success(snapshot(rubRate: 100))
            ])
            let vm = viewModel(
                items: [
                    item(title: title, amount: amount, currencyCode: "USD", cycle: cycle),
                    item(title: "Monthly", amount: 15, currencyCode: "USD")
                ],
                preferences: fixture.repository,
                provider: provider
            )

            vm.sortOrder = .amountAsc
            vm.load()
            await refresh(vm)

            #expect(vm.filteredItems.map(\.title) == [title, "Monthly"])
            #expect(await provider.requests() == 1)
        }
    }

    @Test("Missing rates place unavailable amount keys after comparable values deterministically")
    func unavailableAmountSortKeysNeverFallBackToRawValues() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 100))
        ])
        let vm = viewModel(
            items: [
                item(title: "Known", amount: 100, currencyCode: "RUB"),
                item(title: "Unavailable B", amount: 2, currencyCode: "EUR"),
                item(title: "Unavailable A", amount: 1, currencyCode: "JPY")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc
        vm.load()
        await refresh(vm)

        let expected = ["Known", "Unavailable A", "Unavailable B"]
        #expect(vm.filteredItems.map(\.title) == expected)
        #expect(vm.filteredMonthlyAggregation?.missingCurrencyCodes == ["EUR", "JPY"])

        vm.sortOrder = .amountDesc

        #expect(vm.filteredItems.map(\.title) == expected)
    }

    @Test("Search and status filters keep amount sorting within the visible rows")
    func amountSortingPreservesSearchAndStatusFilterContracts() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 100))
        ])
        let vm = viewModel(
            items: [
                item(title: "Match RUB", amount: 100, currencyCode: "RUB"),
                item(title: "Match USD", amount: 2, currencyCode: "USD"),
                item(title: "Other", amount: 500, currencyCode: "RUB"),
                item(title: "Paused Match", amount: 3, currencyCode: "USD", status: .paused)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountDesc
        vm.load()
        await refresh(vm)

        await waitForFilteredItemsChange(in: vm) {
            vm.searchText = "Match"
        }

        #expect(vm.filteredItems.map(\.title) == ["Paused Match", "Match USD", "Match RUB"])

        vm.activeFilter = .paused

        #expect(vm.filteredItems.map(\.title) == ["Paused Match"])
        #expect(await provider.requests() == 1)
    }

    @Test("Reporting-currency reload recalculates amount keys without resetting sort mode")
    func reportingCurrencyReloadRecalculatesAmountSortKeys() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 100)),
            .success(snapshot(rubRate: 100))
        ])
        let rub = item(title: "RUB", amount: 100, currencyCode: "RUB")
        let usd = item(title: "USD", amount: 2, currencyCode: "USD")
        let vm = viewModel(
            items: [rub, usd],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc
        vm.load()
        await refresh(vm)
        #expect(vm.defaultCurrency == "RUB")
        #expect(vm.filteredMonthlyAggregation?.total?.amount == 300)

        fixture.save(currencyCode: "USD")
        vm.load()
        await refresh(vm)

        #expect(vm.defaultCurrency == "USD")
        #expect(vm.sortOrder == .amountAsc)
        #expect(vm.filteredItems.map(\.title) == ["RUB", "USD"])
        #expect(vm.filteredMonthlyAggregation?.total?.amount == 3)
        #expect(rub.currencyCode == "RUB")
        #expect(usd.currencyCode == "USD")
        #expect(await provider.requests() == 2)
    }

    @Test("Obsolete exchange-rate results cannot restore a previous reporting-currency amount order")
    func obsoleteRateResultCannotRestorePreviousAmountSortOrder() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let provider = DeferredExchangeRateProvider()
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB"),
                item(title: "USD", amount: 2, currencyCode: "USD")
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.sortOrder = .amountAsc
        vm.load()
        let previousRevision = vm.aggregationRevision
        let previousRefresh = Task {
            await vm.refreshCurrencyAggregation(revision: previousRevision)
        }
        await provider.waitForRequests(1)

        fixture.save(currencyCode: "USD")
        vm.load()
        let currentRevision = vm.aggregationRevision
        let currentRefresh = Task {
            await vm.refreshCurrencyAggregation(revision: currentRevision)
        }
        await provider.waitForRequests(2)

        await provider.resumeRequest(at: 1, with: snapshot(rubRate: 100))
        await currentRefresh.value
        #expect(vm.defaultCurrency == "USD")
        #expect(vm.filteredMonthlyAggregation?.total?.amount == 3)

        await provider.resumeRequest(at: 0, with: snapshot(rubRate: 10))
        await previousRefresh.value

        #expect(vm.defaultCurrency == "USD")
        #expect(vm.aggregationRevision == currentRevision)
        #expect(vm.filteredMonthlyAggregation?.total?.amount == 3)
        #expect(vm.filteredItems.map(\.title) == ["RUB", "USD"])
    }
}
