import Foundation
import Testing
@testable import Soren

@Suite("Calendar currency aggregation")
@MainActor
struct CalendarCurrencyAggregationTests {
    @MainActor
    private final class InMemoryRecurringItemRepository: RecurringItemRepository {
        var items: [RecurringItem]

        init(items: [RecurringItem]) {
            self.items = items
        }

        func fetchAll() throws -> [RecurringItem] { items }

        func fetchActive() throws -> [RecurringItem] {
            let activeStatuses: Set<ItemStatus> = [.active, .dueSoon, .dueToday, .trial]
            return items.filter {
                $0.archivedAt == nil && activeStatuses.contains($0.status)
            }
        }

        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }

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

    private enum RateProviderError: Error, Sendable {
        case unavailable
    }

    private enum RateResponse: Sendable {
        case success(ExchangeRateSnapshot, delay: Duration)
        case failure(RateProviderError, delay: Duration)
    }

    private actor RecordingExchangeRateProvider: ExchangeRateProvider {
        private let responses: [RateResponse]
        private var requestCount = 0

        init(responses: [RateResponse]) {
            self.responses = responses
        }

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            let responseIndex = requestCount
            requestCount += 1
            guard responses.indices.contains(responseIndex) else {
                throw RateProviderError.unavailable
            }

            switch responses[responseIndex] {
            case let .success(snapshot, delay):
                if delay > .zero { try await Task.sleep(for: delay) }
                return snapshot
            case let .failure(error, delay):
                if delay > .zero { try await Task.sleep(for: delay) }
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
        let suiteName = "CalendarCurrencyAggregationTests.\(UUID().uuidString)"
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

    private func displayedMonthStart() throws -> Date {
        let calendar = CalendarViewModel.cal
        return try #require(calendar.date(
            from: calendar.dateComponents([.year, .month], from: .now)
        ))
    }

    private func date(day: Int) throws -> Date {
        let monthStart = try displayedMonthStart()
        return try #require(CalendarViewModel.cal.date(
            byAdding: .day,
            value: day - 1,
            to: monthStart
        ))
    }

    private func snapshot(
        rubRate: Decimal,
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

    private func canonicalFixtureDay(_ carrier: Date) -> Date {
        BillingCivilDay.calendar.date(from: CalendarViewModel.cal.dateComponents([.year, .month, .day], from: carrier)) ?? .distantPast
    }

    private func item(
        title: String,
        amount: Decimal,
        currencyCode: String,
        chargeDate: Date,
        status: ItemStatus = .active,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        archivedAt: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            amount: amount,
            currencyCode: currencyCode,
            startDate: canonicalFixtureDay(chargeDate),
            nextChargeDate: canonicalFixtureDay(chargeDate),
            autoRenew: autoRenew,
            endDate: endDate.map(canonicalFixtureDay),
            status: status,
            archivedAt: archivedAt
        )
    }

    private func viewModel<Provider: ExchangeRateProvider>(
        items: [RecurringItem],
        preferences: UserPreferencesRepository,
        provider: Provider
    ) -> CalendarViewModel {
        CalendarViewModel(
            repository: InMemoryRecurringItemRepository(items: items),
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: provider
        )
    }

    @Test("Mixed month and selected day convert before aggregation while rows stay original")
    func mixedMonthAndSelectedDayConvertBeforeAggregation() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 17)
        let usd = try decimal("12.99")
        let rate = try decimal("76.76")
        let expected = Decimal(299) + usd * rate
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: rate), delay: .zero)
        ])
        let vm = viewModel(
            items: [
                item(title: "IVI", amount: 299, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "Apple TV+", amount: usd, currencyCode: "USD", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)

        guard case let .partial(initialTotal, missingCodes, _) = vm.monthlyAggregation else {
            Issue.record("Expected safe partial total before rates arrive")
            return
        }
        #expect(initialTotal.amount == 299)
        #expect(missingCodes == ["USD"])

        let revision = vm.aggregationRevision
        await vm.refreshCurrencyAggregation(revision: revision)

        #expect(vm.monthlyAggregation?.total?.amount == expected)
        #expect(vm.selectedDayAggregation?.total?.amount == expected)
        #expect(vm.monthlyAggregation?.total?.currencyCode == "RUB")
        #expect(vm.selectedDayCharges.map(\.amount) == [299, usd])
        #expect(vm.selectedDayCharges.map(\.currencyCode) == ["RUB", "USD"])
        let requestCount = await provider.requests()
        #expect(requestCount == 1)
    }

    @Test("Same-currency Calendar does not request FX")
    func sameCurrencySkipsFX() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 12)
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(title: "A", amount: 100, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "B", amount: 500, currencyCode: "RUB", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        #expect(vm.monthlyAggregation?.isComplete == true)
        #expect(vm.monthlyAggregation?.total?.amount == 600)
        #expect(vm.selectedDayAggregation?.total?.amount == 600)
        let requestCount = await provider.requests()
        #expect(requestCount == 0)
    }

    @Test("Missing foreign rate preserves same-currency subtotal without raw fallback")
    func missingRateProducesPartialSubtotal() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 19)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 80), delay: .zero)
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 299, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "GBP", amount: 100, currencyCode: "GBP", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        guard case let .partial(monthlyTotal, monthlyMissing, _) = vm.monthlyAggregation,
              case let .partial(dayTotal, dayMissing, _) = vm.selectedDayAggregation
        else {
            Issue.record("Expected partial Calendar totals")
            return
        }
        #expect(monthlyTotal.amount == 299)
        #expect(dayTotal.amount == 299)
        #expect(monthlyTotal.amount != 399)
        #expect(monthlyMissing == ["GBP"])
        #expect(dayMissing == ["GBP"])
        let requestCount = await provider.requests()
        #expect(requestCount == 1)
    }

    @Test("Only foreign items without rates are unavailable while events stay visible")
    func allForeignWithoutRatesIsUnavailable() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 20)
        let provider = RecordingExchangeRateProvider(responses: [
            .failure(.unavailable, delay: .zero)
        ])
        let vm = viewModel(
            items: [item(
                title: "Apple TV+",
                amount: try decimal("12.99"),
                currencyCode: "USD",
                chargeDate: chargeDate
            )],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        guard case let .unavailable(_, monthlyMissing, _, _) = vm.monthlyAggregation,
              case let .unavailable(_, dayMissing, _, _) = vm.selectedDayAggregation
        else {
            Issue.record("Expected unavailable Calendar totals")
            return
        }
        #expect(monthlyMissing == ["USD"])
        #expect(dayMissing == ["USD"])
        #expect(vm.monthlyAggregation?.total == nil)
        #expect(vm.selectedDayAggregation?.total == nil)
        #expect(vm.selectedDayCharges.map(\.title) == ["Apple TV+"])
        #expect(vm.chargesByDate[chargeDate]?.count == 1)
    }

    @Test("Fresh and stale snapshot metadata are preserved")
    func freshnessMetadataIsPreserved() async throws {
        let chargeDate = try date(day: 21)
        let usd = try decimal("12.99")

        let freshFixture = try preferences()
        defer { freshFixture.cleanUp() }
        let freshProvider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 75, freshness: .fresh), delay: .zero)
        ])
        let freshVM = viewModel(
            items: [item(title: "USD", amount: usd, currencyCode: "USD", chargeDate: chargeDate)],
            preferences: freshFixture.repository,
            provider: freshProvider
        )
        freshVM.load()
        await freshVM.refreshCurrencyAggregation(revision: freshVM.aggregationRevision)
        #expect(freshVM.monthlyAggregation?.rateMetadata?.freshness == .fresh)

        let staleFixture = try preferences()
        defer { staleFixture.cleanUp() }
        let age: TimeInterval = 28_800
        let staleProvider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 75, freshness: .stale(age: age)), delay: .zero)
        ])
        let staleVM = viewModel(
            items: [item(title: "USD", amount: usd, currencyCode: "USD", chargeDate: chargeDate)],
            preferences: staleFixture.repository,
            provider: staleProvider
        )
        staleVM.load()
        staleVM.selectDate(chargeDate)
        await staleVM.refreshCurrencyAggregation(revision: staleVM.aggregationRevision)
        #expect(staleVM.monthlyAggregation?.rateMetadata?.freshness == .stale(age: age))
        #expect(staleVM.selectedDayAggregation?.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("A stale snapshot without a successful foreign Calendar conversion has no metadata")
    func stalePartialCalendarAggregationHasNoMetadataWithoutConversion() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 23)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 80, freshness: .stale(age: 28_800)), delay: .zero)
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 299, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "GBP", amount: 10, currencyCode: "GBP", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        guard case let .partial(monthlyTotal, monthlyMissing, monthlyMetadata) = vm.monthlyAggregation,
              case let .partial(dayTotal, dayMissing, dayMetadata) = vm.selectedDayAggregation
        else {
            Issue.record("Expected partial Calendar aggregations")
            return
        }
        #expect(monthlyTotal.amount == 299)
        #expect(dayTotal.amount == 299)
        #expect(monthlyMissing == ["GBP"])
        #expect(dayMissing == ["GBP"])
        #expect(monthlyMetadata == nil)
        #expect(dayMetadata == nil)
    }

    @Test("A stale snapshot without a convertible Calendar amount remains unavailable")
    func staleUnavailableCalendarAggregationHasNoMetadata() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 24)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 80, freshness: .stale(age: 28_800)), delay: .zero)
        ])
        let vm = viewModel(
            items: [item(title: "GBP", amount: 10, currencyCode: "GBP", chargeDate: chargeDate)],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        guard case let .unavailable(_, monthlyMissing, _, monthlyMetadata) = vm.monthlyAggregation,
              case let .unavailable(_, dayMissing, _, dayMetadata) = vm.selectedDayAggregation
        else {
            Issue.record("Expected unavailable Calendar aggregations")
            return
        }
        #expect(monthlyMissing == ["GBP"])
        #expect(dayMissing == ["GBP"])
        #expect(monthlyMetadata == nil)
        #expect(dayMetadata == nil)
        #expect(vm.monthlyAggregation?.total == nil)
        #expect(vm.selectedDayAggregation?.total == nil)
    }

    @Test("Reporting currency change recalculates totals and preserves Calendar context")
    func reportingCurrencyChangePreservesContextAndOriginalItems() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 22)
        let usd = try decimal("12.99")
        let rubRate = try decimal("76.76")
        let sharedSnapshot = snapshot(rubRate: rubRate)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(sharedSnapshot, delay: .zero),
            .success(sharedSnapshot, delay: .zero)
        ])
        let vm = viewModel(
            items: [
                item(title: "IVI", amount: 299, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "Apple TV+", amount: usd, currencyCode: "USD", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)
        let selectedBefore = vm.selectedDate
        let monthBefore = vm.displayedMonth

        fixture.save(currencyCode: "USD")
        vm.load(forceReload: true)
        guard case let .partial(initialUSDTotal, initialMissingCodes, _) = vm.monthlyAggregation else {
            Issue.record("Expected a safe partial result before the new calculation loads rates")
            return
        }
        #expect(initialUSDTotal.amount == usd)
        #expect(initialMissingCodes == ["RUB"])

        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        let expectedUSD = usd + Decimal(299) / rubRate
        #expect(vm.reportingCurrencyCode == "USD")
        #expect(vm.monthlyAggregation?.total?.amount == expectedUSD)
        #expect(vm.selectedDayAggregation?.total?.amount == expectedUSD)
        #expect(vm.selectedDate == selectedBefore)
        #expect(vm.displayedMonth == monthBefore)
        #expect(vm.selectedDayCharges.map(\.amount) == [299, usd])
        #expect(vm.selectedDayCharges.map(\.currencyCode) == ["RUB", "USD"])
    }

    @Test("Older async result cannot overwrite a newer reporting-currency calculation")
    func olderAsyncResultDoesNotOverwriteNewerCalculation() async throws {
        let fixture = try preferences(currencyCode: "RUB")
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 23)
        let usd = try decimal("12.99")
        let firstRate = Decimal(50)
        let secondRate = Decimal(100)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: firstRate), delay: .milliseconds(150)),
            .success(snapshot(rubRate: secondRate), delay: .zero)
        ])
        let vm = viewModel(
            items: [
                item(title: "RUB", amount: 299, currencyCode: "RUB", chargeDate: chargeDate),
                item(title: "USD", amount: usd, currencyCode: "USD", chargeDate: chargeDate)
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        let firstRevision = vm.aggregationRevision
        let firstRefresh = Task {
            await vm.refreshCurrencyAggregation(revision: firstRevision)
        }

        for _ in 0..<100 where await provider.requests() == 0 {
            await Task.yield()
        }

        fixture.save(currencyCode: "USD")
        vm.load(forceReload: true)
        let secondRevision = vm.aggregationRevision
        await vm.refreshCurrencyAggregation(revision: secondRevision)
        await firstRefresh.value

        let expected = usd + Decimal(299) / secondRate
        #expect(vm.reportingCurrencyCode == "USD")
        #expect(vm.monthlyAggregation?.total?.amount == expected)
        #expect(vm.monthlyAggregation?.total?.amount != usd + Decimal(299) / firstRate)
        let requestCount = await provider.requests()
        #expect(requestCount == 2)
    }

    @Test("Concurrent refresh calls for one revision share one snapshot request")
    func concurrentRefreshUsesOneSnapshot() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 24)
        let provider = RecordingExchangeRateProvider(responses: [
            .success(snapshot(rubRate: 80), delay: .milliseconds(30))
        ])
        let vm = viewModel(
            items: [item(title: "USD", amount: 10, currencyCode: "USD", chargeDate: chargeDate)],
            preferences: fixture.repository,
            provider: provider
        )
        vm.load()
        let revision = vm.aggregationRevision

        let first = Task { await vm.refreshCurrencyAggregation(revision: revision) }
        let second = Task { await vm.refreshCurrencyAggregation(revision: revision) }
        await first.value
        await second.value

        let requestCount = await provider.requests()
        #expect(requestCount == 1)
        #expect(vm.monthlyAggregation?.total?.amount == 800)
    }

    @Test("Cancelled and archived items stay excluded while active finite history follows existing rules")
    func lifecycleRulesRemainUnchanged() async throws {
        let fixture = try preferences()
        defer { fixture.cleanUp() }
        let chargeDate = try date(day: 8)
        let endDate = try date(day: 9)
        let provider = RecordingExchangeRateProvider(responses: [])
        let vm = viewModel(
            items: [
                item(
                    title: "Expired finite history",
                    amount: 100,
                    currencyCode: "RUB",
                    chargeDate: chargeDate,
                    autoRenew: false,
                    endDate: endDate
                ),
                item(
                    title: "Cancelled",
                    amount: 200,
                    currencyCode: "RUB",
                    chargeDate: chargeDate,
                    status: .cancelled
                ),
                item(
                    title: "Archived",
                    amount: 300,
                    currencyCode: "RUB",
                    chargeDate: chargeDate,
                    archivedAt: .now
                )
            ],
            preferences: fixture.repository,
            provider: provider
        )

        vm.load()
        vm.selectDate(chargeDate)
        await vm.refreshCurrencyAggregation(revision: vm.aggregationRevision)

        #expect(vm.selectedDayCharges.map(\.title) == ["Expired finite history"])
        #expect(vm.monthlyAggregation?.total?.amount == 100)
        let requestCount = await provider.requests()
        #expect(requestCount == 0)
    }

    @Test("Calendar aggregation status strings have RU and EN coverage")
    func aggregationStatusStringsAreLocalized() throws {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let englishPath = try #require(appBundle.path(forResource: "en", ofType: "lproj"))
        let russianPath = try #require(appBundle.path(forResource: "ru", ofType: "lproj"))
        let englishBundle = try #require(Bundle(path: englishPath))
        let russianBundle = try #require(Bundle(path: russianPath))
        let codes = "USD, GBP"

        #expect(
            String(
                localized: "Нет курсов для \(codes)",
                bundle: englishBundle,
                locale: Locale(identifier: "en")
            ) == "Missing rates for USD, GBP"
        )
        #expect(
            String(
                localized: "По сохранённому курсу",
                bundle: englishBundle,
                locale: Locale(identifier: "en")
            ) == "Using cached rates"
        )
        #expect(
            String(
                localized: "Нет курсов для \(codes)",
                bundle: russianBundle,
                locale: Locale(identifier: "ru")
            ) == "Нет курсов для USD, GBP"
        )
        #expect(
            String(
                localized: "По сохранённому курсу",
                bundle: russianBundle,
                locale: Locale(identifier: "ru")
            ) == "По сохранённому курсу"
        )
    }
}
