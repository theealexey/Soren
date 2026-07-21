import Foundation
import Testing
@testable import Soren

@Suite("Home currency aggregation")
@MainActor
struct HomeCurrencyAggregationTests {
    @MainActor
    private final class InMemoryRecurringItemRepository: RecurringItemRepository {
        var items: [RecurringItem]

        init(items: [RecurringItem]) {
            self.items = items
        }

        func fetchAll() throws -> [RecurringItem] { items }

        func fetchActive() throws -> [RecurringItem] {
            items.filter { $0.archivedAt == nil && $0.status.countsInTotals }
        }

        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
            let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
            return items.filter {
                $0.archivedAt == nil
                    && $0.nextChargeDate >= date
                    && $0.nextChargeDate <= cutoff
            }
        }

        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
            items.filter { $0.category == category }
        }

        func fetch(id: UUID) throws -> RecurringItem? {
            items.first { $0.id == id }
        }

        func save(_ item: RecurringItem) throws { items.append(item) }

        func update(_ item: RecurringItem) throws {
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[index] = item
        }

        func delete(id: UUID) throws {
            items.removeAll { $0.id == id }
        }

        func saveAll(_ items: [RecurringItem]) throws {
            self.items.append(contentsOf: items)
        }

        func deleteAll() throws { items.removeAll() }
    }

    private actor RecordingExchangeRateProvider: ExchangeRateProvider {
        private let result: Result<ExchangeRateSnapshot, TestRateError>
        private var requestCount = 0

        init(result: Result<ExchangeRateSnapshot, TestRateError>) {
            self.result = result
        }

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            return try result.get()
        }

        func requests() -> Int { requestCount }
    }

    private actor SequenceExchangeRateProvider: ExchangeRateProvider {
        private var results: [Result<ExchangeRateSnapshot, TestRateError>]
        private var requestCount = 0

        init(results: [Result<ExchangeRateSnapshot, TestRateError>]) {
            self.results = results
        }

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            guard !results.isEmpty else { throw TestRateError.unavailable }
            return try results.removeFirst().get()
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

        func failRequest(at index: Int) {
            guard continuations.indices.contains(index) else { return }
            continuations.remove(at: index).resume(throwing: TestRateError.unavailable)
        }
    }

    private enum TestRateError: Error, Sendable {
        case unavailable
    }

    private func snapshot(
        rubRate: Decimal = 90,
        freshness: ExchangeRateFreshness = .fresh
    ) -> ExchangeRateSnapshot {
        let now = Date.now
        return ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: now,
                rates: ["RUB": rubRate],
                fetchedAt: now
            ),
            freshness: freshness
        )
    }

    private func item(
        title: String,
        amount: Decimal,
        currencyCode: String,
        nextChargeDate: Date,
        status: ItemStatus = .active
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            nextChargeDate: nextChargeDate,
            status: status
        )
    }

    private func preferences() throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suiteName = "HomeCurrencyAggregationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserPreferencesRepository(defaults: defaults)
        savePreferences(repository, currencyCode: "RUB")
        return (repository, defaults, suiteName)
    }

    private func savePreferences(
        _ repository: UserPreferencesRepository,
        currencyCode: String
    ) {
        repository.save(UserPreferences(
            defaultCurrencyCode: currencyCode,
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))
    }

    private func viewModel<Provider: ExchangeRateProvider>(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: Provider
    ) -> HomeViewModel {
        let repository = InMemoryRecurringItemRepository(items: items)
        return HomeViewModel(
            getUpcomingCharges: GetUpcomingCharges(repository: repository),
            getActiveTrials: GetActiveTrials(repository: repository),
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: provider
        )
    }

    @Test("Home converts mixed currencies before forecast and landscape aggregation")
    func mixedCurrenciesConvertBeforeHomeTotals() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot()))
        let vm = viewModel(
            items: [
                item(title: "USD item", amount: 100, currencyCode: "USD", nextChargeDate: chargeDate),
                item(title: "RUB item", amount: 500, currencyCode: "RUB", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()

        guard case let .partial(initialTotal, missingCodes, _) = vm.forecastAggregation else {
            Issue.record("Expected a safe partial result before rates arrive")
            return
        }
        #expect(initialTotal.amount == 500)
        #expect(initialTotal.amount != 600)
        #expect(missingCodes == ["USD"])

        await vm.refreshCurrencyAggregation()

        let total = try #require(vm.forecastAggregation?.total)
        #expect(vm.forecastAggregation?.isComplete == true)
        #expect(total.amount == 9_500)
        #expect(total.currencyCode == "RUB")
        #expect(vm.landscapePoints.first(where: { $0.chargeCount == 2 })?.rawTotal == 9_500)
        let requestCount = await provider.requests()
        #expect(requestCount == 1)

        let usdItem = try #require(vm.upcomingCharges.first { $0.title == "USD item" })
        #expect(usdItem.amount == 100)
        #expect(usdItem.currencyCode == "USD")
    }

    @Test("Same-currency Home skips the exchange-rate provider")
    func sameCurrencySkipsProvider() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(
            result: .success(snapshot(freshness: .stale(age: 7_200)))
        )
        let vm = viewModel(
            items: [
                item(title: "A", amount: 100, currencyCode: "RUB", nextChargeDate: chargeDate),
                item(title: "B", amount: 500, currencyCode: "RUB", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.isComplete == true)
        #expect(vm.forecastAggregation?.total?.amount == 600)
        let requestCount = await provider.requests()
        #expect(requestCount == 0)
        #expect(vm.exchangeRateNotice == .none)
        #expect(vm.screenState.exchangeRateNotice == .none)
    }

    @Test("Fresh foreign conversion has no Home stale-rate notice")
    func freshForeignConversionHasNoStaleNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot()))
        let vm = viewModel(
            items: [item(title: "USD", amount: 2, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.amount == 180)
        #expect(vm.exchangeRateNotice == .none)
        #expect(vm.landscapePoints.first { $0.chargeCount == 1 }?.rateMetadata?.freshness == .fresh)
    }

    @Test("Stale foreign conversion retains values and presents one Home stale-rate notice")
    func staleForeignConversionPresentsNoticeAndPreservesDailyMetadata() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let usd = item(title: "USD", amount: 2, currencyCode: "USD", nextChargeDate: chargeDate)
        let provider = RecordingExchangeRateProvider(result: .success(snapshot(freshness: .stale(age: age))))
        let vm = viewModel(items: [usd], preferences: preferences, provider: provider)

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.amount == 180)
        #expect(vm.exchangeRateNotice == .stale(age: age))
        #expect(vm.screenState.exchangeRateNotice == .stale(age: age))

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.rawTotal == 180)
        #expect(point.rateMetadata?.freshness == .stale(age: age))

        vm.selectDate(chargeDate)
        let selection = try #require(vm.selection)
        #expect(selection.totalFormatted.contains("180"))
        #expect(selection.rateMetadata?.freshness == .stale(age: age))
        #expect(usd.amount == 2)
        #expect(usd.currencyCode == "USD")
        #expect(await provider.requests() == 1)
    }

    @Test("An empty Home does not request or present stale FX")
    func emptyHomeHasNoStaleNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let provider = RecordingExchangeRateProvider(
            result: .success(snapshot(freshness: .stale(age: 7_200)))
        )
        let vm = viewModel(items: [], preferences: preferences, provider: provider)

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.amount == 0)
        #expect(vm.exchangeRateNotice == .none)
        #expect(await provider.requests() == 0)
    }

    @Test("Foreign charges outside the Home window do not present stale FX")
    func outsideWindowForeignChargeHasNoStaleNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let outsideWindow = Calendar.current.date(byAdding: .day, value: 40, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(
            result: .success(snapshot(freshness: .stale(age: 7_200)))
        )
        let vm = viewModel(
            items: [item(title: "Later USD", amount: 2, currencyCode: "USD", nextChargeDate: outsideWindow)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.amount == 0)
        #expect(vm.exchangeRateNotice == .none)
        #expect(await provider.requests() == 0)
    }

    @Test("Partial Home aggregate keeps stale notice only when a foreign conversion succeeded")
    func partialStaleAggregatePreservesBothMetadataKinds() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot(freshness: .stale(age: age))))
        let vm = viewModel(
            items: [
                item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: chargeDate),
                item(title: "EUR", amount: 1, currencyCode: "EUR", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        guard case let .partial(total, missingCodes, metadata) = vm.forecastAggregation else {
            Issue.record("Expected stale partial aggregation")
            return
        }
        #expect(total.amount == 90)
        #expect(missingCodes == ["EUR"])
        #expect(metadata?.freshness == .stale(age: age))
        #expect(vm.exchangeRateNotice == .stale(age: age))

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 2 })
        #expect(point.financialState == .partial(amount: 90, missingCurrencyCodes: ["EUR"]))
        #expect(point.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("Unavailable Home aggregate never presents stale FX as a successful value")
    func unavailableStaleSnapshotHasNoNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(
            result: .success(snapshot(freshness: .stale(age: 7_200)))
        )
        let vm = viewModel(
            items: [item(title: "EUR", amount: 1, currencyCode: "EUR", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total == nil)
        #expect(vm.exchangeRateNotice == .none)
        #expect(vm.landscapePoints.first { $0.chargeCount == 1 }?.rawTotal == nil)
    }

    @Test("A stale partial subtotal without a successful foreign conversion has no Home stale-rate notice")
    func stalePartialWithoutForeignConversionHasNoNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(
            result: .success(snapshot(freshness: .stale(age: 7_200)))
        )
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB", nextChargeDate: chargeDate),
                item(title: "EUR", amount: 1, currencyCode: "EUR", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        guard case let .partial(total, missingCodes, metadata) = vm.forecastAggregation else {
            Issue.record("Expected stale partial aggregation without a foreign conversion")
            return
        }
        #expect(total.amount == 100)
        #expect(missingCodes == ["EUR"])
        #expect(metadata == nil)
        #expect(vm.exchangeRateNotice == .none)
    }

    @Test("A stale conversion of a real foreign zero remains available and visible")
    func staleForeignZeroRetainsNumericStateAndNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot(freshness: .stale(age: age))))
        let vm = viewModel(
            items: [item(title: "Free USD", amount: 0, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.amount == 0)
        #expect(vm.exchangeRateNotice == .stale(age: age))
        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.financialState == .complete(amount: 0))
        #expect(point.rawTotal == 0)
        #expect(point.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("Fresh and stale reloads replace the Home FX notice atomically")
    func freshAndStaleReloadsReplaceNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = SequenceExchangeRateProvider(results: [
            .success(snapshot(freshness: .stale(age: age))),
            .success(snapshot()),
            .success(snapshot(freshness: .stale(age: age)))
        ])
        let vm = viewModel(
            items: [item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()
        #expect(vm.exchangeRateNotice == .stale(age: age))

        vm.load(forceReload: true)
        await vm.refreshCurrencyAggregation()
        #expect(vm.exchangeRateNotice == .none)

        vm.load(forceReload: true)
        await vm.refreshCurrencyAggregation()
        #expect(vm.exchangeRateNotice == .stale(age: age))
        #expect(await provider.requests() == 3)
    }

    @Test("Reporting currency recalculates the Home stale notice")
    func reportingCurrencyChangeRecalculatesStaleNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot(freshness: .stale(age: age))))
        let vm = viewModel(
            items: [item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()
        #expect(vm.exchangeRateNotice == .stale(age: age))

        savePreferences(preferences, currencyCode: "USD")
        vm.load(forceReload: true)
        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.total?.currencyCode == "USD")
        #expect(vm.exchangeRateNotice == .none)
        #expect(await provider.requests() == 1)
    }

    @Test("An obsolete stale snapshot cannot restore a stale notice over current fresh Home values")
    func obsoleteStaleSnapshotCannotOverwriteFreshNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = DeferredExchangeRateProvider()
        let vm = viewModel(
            items: [item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        let staleRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(1)

        vm.load(forceReload: true)
        let freshRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(2)

        await provider.resumeRequest(at: 1, with: snapshot())
        await freshRefresh.value
        #expect(vm.exchangeRateNotice == .none)

        await provider.resumeRequest(at: 0, with: snapshot(freshness: .stale(age: 7_200)))
        await staleRefresh.value
        #expect(vm.exchangeRateNotice == .none)
    }

    @Test("An obsolete fresh snapshot cannot hide a current stale Home notice")
    func obsoleteFreshSnapshotCannotOverwriteStaleNotice() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let age: TimeInterval = 7_200
        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = DeferredExchangeRateProvider()
        let vm = viewModel(
            items: [item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        let freshRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(1)

        vm.load(forceReload: true)
        let staleRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(2)

        await provider.resumeRequest(at: 1, with: snapshot(freshness: .stale(age: age)))
        await staleRefresh.value
        #expect(vm.exchangeRateNotice == .stale(age: age))

        await provider.resumeRequest(at: 0, with: snapshot())
        await freshRefresh.value
        #expect(vm.exchangeRateNotice == .stale(age: age))
    }

    @Test("FX failure keeps Home partial and never restores a raw mixed sum")
    func rateFailureKeepsSafePartialResult() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 4, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
        let vm = viewModel(
            items: [
                item(title: "USD item", amount: 100, currencyCode: "USD", nextChargeDate: chargeDate),
                item(title: "RUB item", amount: 500, currencyCode: "RUB", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        guard case let .partial(total, missingCodes, metadata) = vm.forecastAggregation else {
            Issue.record("Expected partial aggregation after FX failure")
            return
        }
        #expect(total.amount == 500)
        #expect(total.amount != 600)
        #expect(missingCodes == ["USD"])
        #expect(metadata == nil)
        let requestCount = await provider.requests()
        #expect(requestCount == 1)
        #expect(!vm.insights.contains { $0.id == .peak })
    }

    @Test("All-foreign Home is unavailable until a snapshot arrives")
    func allForeignWithoutRatesIsUnavailable() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 5, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
        let vm = viewModel(
            items: [item(
                title: "USD item",
                amount: 12,
                currencyCode: "USD",
                nextChargeDate: chargeDate
            )],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        guard case let .unavailable(code, missingCodes, reason, _) = vm.forecastAggregation else {
            Issue.record("Expected unavailable aggregation")
            return
        }
        #expect(code == "RUB")
        #expect(missingCodes == ["USD"])
        #expect(reason == .noConvertibleAmounts)
        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.financialState == .unavailable(
            missingCurrencyCodes: ["USD"],
            reason: .noConvertibleAmounts
        ))
        #expect(point.rawTotal == nil)
        #expect(point.normalizedHeight == nil)
        #expect(BillingLandscapeChartView.numericPoints(from: vm.landscapePoints).isEmpty)
        #expect(!vm.insights.contains { $0.id == .peak })

        guard case let .nextPayment(_, _, amountFormatted, _) = vm.callout else {
            Issue.record("Expected the unavailable charge to remain the Home hero")
            return
        }
        #expect(amountFormatted == String(localized: "Курсы валют недоступны"))
    }

    @Test("Paused and cancelled items never contribute to the Home forecast or selected day")
    func inactiveItemsAreExcludedFromForecastAndSelection() throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let active = item(
            title: "Active",
            amount: 299,
            currencyCode: "RUB",
            nextChargeDate: chargeDate
        )
        let paused = item(
            title: "Paused",
            amount: 500,
            currencyCode: "RUB",
            nextChargeDate: chargeDate,
            status: .paused
        )
        let cancelled = item(
            title: "Cancelled",
            amount: 700,
            currencyCode: "RUB",
            nextChargeDate: chargeDate,
            status: .cancelled
        )
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
        let vm = viewModel(
            items: [active, paused, cancelled],
            preferences: preferences,
            provider: provider
        )

        vm.load()

        #expect(vm.forecastAggregation?.total?.amount == 299)
        let dayPoint = try #require(vm.landscapePoints.first { $0.chargeCount > 0 })
        #expect(dayPoint.chargeCount == 1)
        #expect(dayPoint.rawTotal == 299)

        vm.selectDate(chargeDate)
        let selection = try #require(vm.selection)
        #expect(selection.charges.map(\.id) == [active.id])
        #expect(vm.calloutNavigationItem?.id == active.id)

        // Home's existing upcoming-row contract stays status-filtered and the originals stay intact.
        #expect(vm.upcomingCharges.map(\.id) == [active.id])
        #expect(paused.status == .paused)
        #expect(cancelled.status == .cancelled)
        #expect(paused.amount == 500)
        #expect(cancelled.amount == 700)
    }

    @Test("Paused and cancelled items never become the default Home hero", arguments: [
        ItemStatus.paused,
        ItemStatus.cancelled
    ])
    func inactiveStatusNeverBecomesDefaultHero(status: ItemStatus) throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
        let vm = viewModel(
            items: [item(
                title: status.rawValue,
                amount: 999,
                currencyCode: "RUB",
                nextChargeDate: chargeDate,
                status: status
            )],
            preferences: preferences,
            provider: provider
        )

        vm.load()

        #expect(vm.callout == .noUpcoming)
        #expect(vm.calloutNavigationItem == nil)
        #expect(vm.forecastAggregation?.total?.amount == 0)
        #expect(vm.landscapePoints.allSatisfy { $0.chargeCount == 0 && $0.rawTotal == 0 })
        #expect(!vm.insights.contains { $0.id == .peak })
    }

    @Test("Home converts active foreign items while excluded foreign items do not make the result partial")
    func activeMixedCurrencyStillConvertsAfterStatusFiltering() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .success(snapshot()))
        let vm = viewModel(
            items: [
                item(title: "Active RUB", amount: 500, currencyCode: "RUB", nextChargeDate: chargeDate),
                item(title: "Active USD", amount: 10, currencyCode: "USD", nextChargeDate: chargeDate),
                item(
                    title: "Paused USD",
                    amount: 90,
                    currencyCode: "USD",
                    nextChargeDate: chargeDate,
                    status: .paused
                )
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        guard case let .partial(initialTotal, missingCodes, _) = vm.forecastAggregation else {
            Issue.record("Expected only the active USD charge to await conversion")
            return
        }
        #expect(initialTotal.amount == 500)
        #expect(missingCodes == ["USD"])

        await vm.refreshCurrencyAggregation()

        #expect(vm.forecastAggregation?.isComplete == true)
        #expect(vm.forecastAggregation?.total?.amount == 1_400)
        #expect(vm.landscapePoints.first(where: { $0.chargeCount == 2 })?.rawTotal == 1_400)
        let requestCount = await provider.requests()
        #expect(requestCount == 1)
    }

    @Test("Unavailable daily state remains non-numeric while an available day remains chartable")
    func unavailableDailyStateDoesNotBecomeZeroPointOrSelectedDayTotal() throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let calendar = Calendar.current
        let rubDate = calendar.date(byAdding: .day, value: 2, to: .now) ?? .now
        let usdDate = calendar.date(byAdding: .day, value: 4, to: .now) ?? .now
        let usd = item(title: "USD", amount: 3, currencyCode: "USD", nextChargeDate: usdDate)
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB", nextChargeDate: rubDate),
                usd
            ],
            preferences: preferences,
            provider: RecordingExchangeRateProvider(result: .failure(.unavailable))
        )

        vm.load()

        let rubPoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: rubDate)
        })
        let usdPoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: usdDate)
        })
        #expect(rubPoint.financialState == .complete(amount: 100))
        #expect(rubPoint.rawTotal == 100)
        #expect(rubPoint.normalizedHeight == 1)
        #expect(usdPoint.financialState == .unavailable(
            missingCurrencyCodes: ["USD"],
            reason: .noConvertibleAmounts
        ))
        #expect(usdPoint.rawTotal == nil)
        #expect(usdPoint.normalizedHeight == nil)

        let chartPoints = BillingLandscapeChartView.numericPoints(from: vm.landscapePoints)
        #expect(chartPoints.contains { $0.id == rubPoint.id })
        #expect(!chartPoints.contains { $0.id == usdPoint.id })
        #expect(!vm.insights.contains { $0.id == .peak })

        vm.selectDate(usdDate)
        let selection = try #require(vm.selection)
        #expect(selection.financialState == .unavailable(
            missingCurrencyCodes: ["USD"],
            reason: .noConvertibleAmounts
        ))
        #expect(selection.totalFormatted == String(localized: "Курсы валют недоступны"))
        #expect(vm.calloutNavigationItem?.id == usd.id)
    }

    @Test("A real zero daily total remains distinct from an unavailable conversion")
    func realZeroAndUnavailableDailyStatesRemainDistinct() throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let calendar = Calendar.current
        let zeroDate = calendar.date(byAdding: .day, value: 2, to: .now) ?? .now
        let unavailableDate = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        let vm = viewModel(
            items: [
                item(title: "Free", amount: 0, currencyCode: "RUB", nextChargeDate: zeroDate),
                item(title: "Foreign", amount: 3, currencyCode: "USD", nextChargeDate: unavailableDate)
            ],
            preferences: preferences,
            provider: RecordingExchangeRateProvider(result: .failure(.unavailable))
        )

        vm.load()

        let zeroPoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: zeroDate)
        })
        let unavailablePoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: unavailableDate)
        })
        #expect(zeroPoint.financialState == .complete(amount: 0))
        #expect(zeroPoint.rawTotal == 0)
        #expect(zeroPoint.normalizedHeight == 0)
        #expect(unavailablePoint.rawTotal == nil)
        #expect(unavailablePoint.normalizedHeight == nil)

        let chartPoints = BillingLandscapeChartView.numericPoints(from: vm.landscapePoints)
        #expect(chartPoints.contains { $0.id == zeroPoint.id })
        #expect(!chartPoints.contains { $0.id == unavailablePoint.id })
    }

    @Test("Partial daily state retains only the known subtotal and missing currency metadata")
    func partialDailyStateRetainsKnownSubtotal() throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 100, currencyCode: "RUB", nextChargeDate: chargeDate),
                item(title: "USD", amount: 3, currencyCode: "USD", nextChargeDate: chargeDate)
            ],
            preferences: preferences,
            provider: RecordingExchangeRateProvider(result: .failure(.unavailable))
        )

        vm.load()

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 2 })
        #expect(point.financialState == .partial(amount: 100, missingCurrencyCodes: ["USD"]))
        #expect(point.rawTotal == 100)
        #expect(point.normalizedHeight == 1)

        vm.selectDate(chargeDate)
        let selection = try #require(vm.selection)
        #expect(selection.financialState == .partial(amount: 100, missingCurrencyCodes: ["USD"]))
    }

    @Test("A fresh snapshot restores unavailable daily points without mutating originals")
    func freshSnapshotRestoresCompleteDailyState() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let usd = item(title: "USD", amount: 3, currencyCode: "USD", nextChargeDate: chargeDate)
        let provider = RecordingExchangeRateProvider(result: .success(snapshot()))
        let vm = viewModel(items: [usd], preferences: preferences, provider: provider)

        vm.load()
        vm.selectDate(chargeDate)
        #expect(vm.selection?.financialState == .unavailable(
            missingCurrencyCodes: ["USD"],
            reason: .noConvertibleAmounts
        ))

        await vm.refreshCurrencyAggregation()

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.financialState == .complete(amount: 270))
        #expect(point.rawTotal == 270)
        #expect(point.normalizedHeight == 1)
        #expect(BillingLandscapeChartView.numericPoints(from: vm.landscapePoints).contains {
            $0.id == point.id
        })
        #expect(vm.selection?.financialState == .complete(amount: 270))
        #expect(usd.amount == 3)
        #expect(usd.currencyCode == "USD")
        #expect(await provider.requests() == 1)
    }

    @Test("Reporting-currency reload rebuilds typed daily points without another snapshot")
    func reportingCurrencyReloadRebuildsTypedDailyPoints() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let calendar = Calendar.current
        let rubDate = calendar.date(byAdding: .day, value: 2, to: .now) ?? .now
        let usdDate = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        let rub = item(title: "RUB", amount: 90, currencyCode: "RUB", nextChargeDate: rubDate)
        let usd = item(title: "USD", amount: 1, currencyCode: "USD", nextChargeDate: usdDate)
        let provider = RecordingExchangeRateProvider(result: .success(snapshot()))
        let vm = viewModel(items: [rub, usd], preferences: preferences, provider: provider)

        vm.load()
        await vm.refreshCurrencyAggregation()
        #expect(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: rubDate)
        }?.currencyCode == "RUB")

        savePreferences(preferences, currencyCode: "USD")
        vm.load(forceReload: true)

        let rubPoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: rubDate)
        })
        let usdPoint = try #require(vm.landscapePoints.first {
            calendar.isDate($0.date, inSameDayAs: usdDate)
        })
        #expect(rubPoint.currencyCode == "USD")
        #expect(usdPoint.currencyCode == "USD")
        #expect(rubPoint.financialState == .complete(amount: 1))
        #expect(usdPoint.financialState == .complete(amount: 1))
        #expect(rub.amount == 90)
        #expect(rub.currencyCode == "RUB")
        #expect(usd.amount == 1)
        #expect(usd.currencyCode == "USD")
        #expect(await provider.requests() == 1)
    }

    @Test("Obsolete FX completions cannot overwrite the current unavailable daily state")
    func obsoleteCompleteCannotReplaceCurrentUnavailableDailyState() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = DeferredExchangeRateProvider()
        let vm = viewModel(
            items: [item(title: "USD", amount: 3, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        let oldRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(1)

        vm.load(forceReload: true)
        await provider.resumeRequest(at: 0, with: snapshot())
        await oldRefresh.value

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.financialState == .unavailable(
            missingCurrencyCodes: ["USD"],
            reason: .noConvertibleAmounts
        ))
        #expect(point.rawTotal == nil)
    }

    @Test("Obsolete FX failures cannot overwrite the current complete daily state")
    func obsoleteFailureCannotReplaceCurrentCompleteDailyState() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
        let provider = DeferredExchangeRateProvider()
        let vm = viewModel(
            items: [item(title: "USD", amount: 3, currencyCode: "USD", nextChargeDate: chargeDate)],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        let oldRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(1)

        vm.load(forceReload: true)
        let currentRefresh = Task { await vm.refreshCurrencyAggregation() }
        await provider.waitForRequests(2)

        await provider.resumeRequest(at: 1, with: snapshot())
        await currentRefresh.value
        await provider.failRequest(at: 0)
        await oldRefresh.value

        let point = try #require(vm.landscapePoints.first { $0.chargeCount == 1 })
        #expect(point.financialState == .complete(amount: 270))
        #expect(point.rawTotal == 270)
    }

    @Test("Excluded foreign items neither request FX nor create missing-currency state")
    func excludedForeignItemsDoNotAffectFXAggregation() async throws {
        let (preferences, defaults, suiteName) = try preferences()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let chargeDate = Calendar.current.date(byAdding: .day, value: 4, to: .now) ?? .now
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
        let vm = viewModel(
            items: [
                item(
                    title: "Paused USD",
                    amount: 10,
                    currencyCode: "USD",
                    nextChargeDate: chargeDate,
                    status: .paused
                ),
                item(
                    title: "Cancelled EUR",
                    amount: 20,
                    currencyCode: "EUR",
                    nextChargeDate: chargeDate,
                    status: .cancelled
                )
            ],
            preferences: preferences,
            provider: provider
        )

        vm.load()
        await vm.refreshCurrencyAggregation()

        guard case let .complete(total, metadata) = vm.forecastAggregation else {
            Issue.record("Expected excluded foreign items to leave a complete zero total")
            return
        }
        #expect(total.amount == 0)
        #expect(total.currencyCode == "RUB")
        #expect(metadata == nil)
        #expect(vm.forecastAggregation?.missingCurrencyCodes == [])
        #expect(vm.exchangeRateNotice == .none)
        let requestCount = await provider.requests()
        #expect(requestCount == 0)
    }
}
