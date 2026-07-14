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

    private enum TestRateError: Error, Sendable {
        case unavailable
    }

    private func snapshot(rubRate: Decimal = 90) -> ExchangeRateSnapshot {
        let now = Date.now
        return ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: now,
                rates: ["RUB": rubRate],
                fetchedAt: now
            ),
            freshness: .fresh
        )
    }

    private func item(
        title: String,
        amount: Decimal,
        currencyCode: String,
        nextChargeDate: Date
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            nextChargeDate: nextChargeDate
        )
    }

    private func preferences() throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suiteName = "HomeCurrencyAggregationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserPreferencesRepository(defaults: defaults)
        repository.save(UserPreferences(
            defaultCurrencyCode: "RUB",
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))
        return (repository, defaults, suiteName)
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
        let provider = RecordingExchangeRateProvider(result: .failure(.unavailable))
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
        #expect(vm.landscapePoints.first(where: { $0.chargeCount == 1 })?.rawTotal == 0)
    }
}
