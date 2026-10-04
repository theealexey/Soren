import Foundation
import Testing
@testable import Soren

@Suite("Add/Edit — derived currency estimate")
@MainActor
struct CurrencyEstimateFormTests {

    private enum TestError: Error {
        case timeout
    }

    private enum StubProviderError: Error, Sendable {
        case unavailable
        case missingResponse
    }

    private actor StubExchangeRateProvider: ExchangeRateProvider {
        enum Response: Sendable {
            case success(ExchangeRateSnapshot, delay: Duration = .zero)
            case failure(delay: Duration = .zero)
        }

        private var responses: [Response]
        private var requestCount = 0

        init(responses: [Response]) {
            self.responses = responses
        }

        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            requestCount += 1
            guard !responses.isEmpty else {
                throw StubProviderError.missingResponse
            }

            let response = responses.removeFirst()
            switch response {
            case .success(let snapshot, let delay):
                if delay > .zero {
                    try? await Task.sleep(for: delay)
                }
                return snapshot
            case .failure(let delay):
                if delay > .zero {
                    try? await Task.sleep(for: delay)
                }
                throw StubProviderError.unavailable
            }
        }

        func recordedRequestCount() -> Int {
            requestCount
        }
    }

    @MainActor
    private final class RecordingRecurringItemRepository: RecurringItemRepository {
        private(set) var items: [RecurringItem]
        private(set) var savedItems: [RecurringItem] = []
        private(set) var updatedItems: [RecurringItem] = []

        init(items: [RecurringItem] = []) {
            self.items = items
        }

        func fetchAll() throws -> [RecurringItem] { items }

        func fetchActive() throws -> [RecurringItem] {
            items.filter { $0.status == .active }
        }

        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
            let cutoff = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
            return items.filter { $0.nextChargeDate >= date && $0.nextChargeDate <= cutoff }
        }

        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
            items.filter { $0.category == category }
        }

        func fetch(id: UUID) throws -> RecurringItem? {
            items.first { $0.id == id }
        }

        func save(_ item: RecurringItem) throws {
            savedItems.append(item)
            items.append(item)
        }

        func update(_ item: RecurringItem) throws {
            updatedItems.append(item)
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                items.append(item)
            }
        }

        func delete(id: UUID) throws {
            items.removeAll { $0.id == id }
        }

        func saveAll(_ items: [RecurringItem]) throws {
            self.items.append(contentsOf: items)
            savedItems.append(contentsOf: items)
        }

        func deleteAll() throws {
            items.removeAll()
        }
    }

    private struct PreferencesFixture {
        let suiteName: String
        let defaults: UserDefaults
        let repository: UserPreferencesRepository

        func setReportingCurrency(_ currencyCode: String) {
            var preferences = repository.load()
            preferences.defaultCurrencyCode = currencyCode
            repository.save(preferences)
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private let rateDate = Date(timeIntervalSince1970: 1_750_000_000)
    private let fetchedAt = Date(timeIntervalSince1970: 1_750_000_100)

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value))
    }

    private func snapshot(
        rubRate: Decimal = 90,
        eurRate: Decimal = 0.9,
        freshness: ExchangeRateFreshness = .fresh
    ) -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: rateDate,
                rates: ["RUB": rubRate, "EUR": eurRate],
                fetchedAt: fetchedAt
            ),
            freshness: freshness
        )
    }

    private func makePreferences(reportingCurrency: String) throws -> PreferencesFixture {
        let suiteName = "CurrencyEstimateFormTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let repository = UserPreferencesRepository(defaults: defaults)
        let fixture = PreferencesFixture(
            suiteName: suiteName,
            defaults: defaults,
            repository: repository
        )
        fixture.setReportingCurrency(reportingCurrency)
        return fixture
    }

    private func makeService<Provider: ExchangeRateProvider>(
        provider: Provider
    ) -> CurrencyEstimateService {
        CurrencyEstimateService(
            exchangeRateProvider: provider,
            convertMoney: ConvertMoneyUseCase()
        )
    }

    private func makeAddViewModel<Provider: ExchangeRateProvider>(
        repository: RecordingRecurringItemRepository,
        preferences: UserPreferencesRepository,
        provider: Provider,
        catalog: [ProviderTemplate] = [],
        regionalPricingSnapshotResult: Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> = .failure(.resourceNotFound("RegionalPricing"))
    ) -> AddSubscriptionViewModel {
        AddSubscriptionViewModel(
            catalog: InMemoryProviderCatalogRepository(providers: catalog),
            saveRecurringItem: SaveRecurringItem(repository: repository),
            currencyEstimateService: makeService(provider: provider),
            preferences: preferences,
            regionalPricingSnapshotResult: regionalPricingSnapshotResult
        )
    }

    private func makeEditViewModel<Provider: ExchangeRateProvider>(
        item: RecurringItem,
        repository: RecordingRecurringItemRepository,
        preferences: UserPreferencesRepository,
        provider: Provider
    ) -> ItemDetailsViewModel {
        ItemDetailsViewModel(
            item: item,
            updateRecurringItem: UpdateRecurringItem(repository: repository),
            deleteRecurringItem: DeleteRecurringItem(repository: repository),
            currencyEstimateService: makeService(provider: provider),
            preferences: preferences
        )
    }

    private func makeItem(amount: Decimal = 12, currencyCode: String = "USD") -> RecurringItem {
        RecurringItem(
            title: "Test Subscription",
            providerName: "Test Subscription",
            amount: amount,
            currencyCode: currencyCode,
            startDate: BillingCivilDay.calendar.startOfDay(for: .now),
            nextChargeDate: BillingCivilDay.calendar.date(byAdding: .month, value: 1, to: BillingCivilDay.calendar.startOfDay(for: .now)) ?? BillingCivilDay.calendar.startOfDay(for: .now)
        )
    }

    private func waitForAvailable(
        _ state: @escaping @MainActor () -> CurrencyEstimateState
    ) async throws -> ConversionResult {
        for _ in 0..<100 {
            if case .available(let result) = state() {
                return result
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for an available currency estimate")
        throw TestError.timeout
    }

    private func waitForUnavailable(
        _ state: @escaping @MainActor () -> CurrencyEstimateState
    ) async throws {
        for _ in 0..<100 {
            if case .unavailable = state() {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for an unavailable currency estimate")
        throw TestError.timeout
    }

    private func localizationBundle(_ languageCode: String) throws -> Bundle {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test("Add persists the original 12 USD, not the RUB estimate")
    func addPersistsOriginalMoney() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.title = "Original"
        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        _ = try await waitForAvailable { viewModel.currencyEstimateState }
        try await viewModel.save()

        let saved = try #require(repository.savedItems.first)
        #expect(saved.amount == 12)
        #expect(saved.currencyCode == "USD")
    }

    @Test("Edit starts from and persists the stored original 12 USD")
    func editPreservesOriginalMoney() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let item = makeItem()
        let repository = RecordingRecurringItemRepository(items: [item])
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeEditViewModel(
            item: item,
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.startEditing()
        #expect(viewModel.editAmountText == "12")
        #expect(viewModel.editCurrencyCode == "USD")
        _ = try await waitForAvailable { viewModel.currencyEstimateState }
        try await viewModel.saveChanges()

        let updated = try #require(repository.updatedItems.last)
        #expect(updated.amount == 12)
        #expect(updated.currencyCode == "USD")
    }

    @Test("RUB estimate is derived without mutating original form values")
    func estimateDoesNotMutateOriginal() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        let result = try await waitForAvailable { viewModel.currencyEstimateState }

        #expect(result.original == (try Money(amount: 12, currencyCode: "USD")))
        #expect(result.converted == (try Money(amount: 1_080, currencyCode: "RUB")))
        #expect(viewModel.amountText == "12")
        #expect(viewModel.currencyCode == "USD")
    }

    @Test("Changing reporting currency recalculates only the estimate")
    func reportingCurrencyChangeOnlyRecalculatesEstimate() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(
            responses: [.success(snapshot()), .success(snapshot())]
        )
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        let rubResult = try await waitForAvailable { viewModel.currencyEstimateState }
        #expect(rubResult.converted.currencyCode == "RUB")

        preferences.setReportingCurrency("EUR")
        viewModel.refreshReportingCurrency()
        let eurResult = try await waitForAvailable {
            guard case .available(let result) = viewModel.currencyEstimateState,
                  result.converted.currencyCode == "EUR"
            else { return .loading }
            return .available(result)
        }

        #expect(eurResult.converted.currencyCode == "EUR")
        #expect(viewModel.amountText == "12")
        #expect(viewModel.currencyCode == "USD")
        #expect(await provider.recordedRequestCount() == 2)
    }

    @Test("Changing original currency never rewrites amountText")
    func originalCurrencyChangeDoesNotRewriteAmount() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(
            responses: [.success(snapshot()), .success(snapshot())]
        )
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        _ = try await waitForAvailable { viewModel.currencyEstimateState }

        viewModel.currencyCode = "EUR"
        let result = try await waitForAvailable {
            guard case .available(let value) = viewModel.currencyEstimateState,
                  value.original.currencyCode == "EUR"
            else { return .loading }
            return .available(value)
        }

        #expect(result.original.amount == 12)
        #expect(viewModel.amountText == "12")
        #expect(viewModel.currencyCode == "EUR")
    }

    @Test("Same-currency input stays hidden and does not request rates")
    func sameCurrencySkipsProvider() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "RUB"
        try await Task.sleep(for: .milliseconds(25))

        #expect(viewModel.currencyEstimateState == .hidden)
        #expect(await provider.recordedRequestCount() == 0)
    }

    @Test("Empty amount hides estimate without requesting rates")
    func emptyAmountHidesEstimate() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.currencyCode = "USD"
        viewModel.amountText = ""
        try await Task.sleep(for: .milliseconds(25))

        #expect(viewModel.currencyEstimateState == .hidden)
        #expect(await provider.recordedRequestCount() == 0)
    }

    @Test("Invalid partial amount stays hidden instead of showing an FX error")
    func invalidPartialAmountStaysHidden() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.failure()])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.currencyCode = "USD"
        viewModel.amountText = "."
        try await Task.sleep(for: .milliseconds(25))

        #expect(viewModel.currencyEstimateState == .hidden)
        #expect(await provider.recordedRequestCount() == 0)
    }

    @Test("FX failure does not block Add save")
    func failureDoesNotBlockSave() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.failure()])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.title = "Offline Save"
        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        try await waitForUnavailable { viewModel.currencyEstimateState }

        #expect(viewModel.canSave)
        try await viewModel.save()
        #expect(repository.savedItems.count == 1)
    }

    @Test("FX failure never relabels or mutates the original currency")
    func failurePreservesOriginalCurrency() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.failure()])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        try await waitForUnavailable { viewModel.currencyEstimateState }

        #expect(viewModel.amountText == "12")
        #expect(viewModel.currencyCode == "USD")
    }

    @Test("Stale snapshot produces a stale estimate state")
    func staleSnapshotState() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(
            responses: [.success(snapshot(freshness: .stale(age: 28_800)))]
        )
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        let result = try await waitForAvailable { viewModel.currencyEstimateState }

        #expect(result.freshness == .stale(age: 28_800))
    }

    @Test("Fresh snapshot produces a fresh estimate state")
    func freshSnapshotState() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.amountText = "12"
        viewModel.currencyCode = "USD"
        let result = try await waitForAvailable { viewModel.currencyEstimateState }

        #expect(result.freshness == .fresh)
    }

    @Test("Obsolete async result cannot overwrite the latest estimate")
    func obsoleteResultCannotOverwriteLatest() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(
            responses: [
                .success(snapshot(rubRate: 10), delay: .milliseconds(150)),
                .success(snapshot(rubRate: 100), delay: .milliseconds(5)),
            ]
        )
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider
        )

        viewModel.currencyCode = "USD"
        viewModel.amountText = "10"
        for _ in 0..<50 {
            if await provider.recordedRequestCount() > 0 {
                break
            }
            try await Task.sleep(for: .milliseconds(2))
        }

        viewModel.amountText = "20"
        let latest = try await waitForAvailable {
            guard case .available(let result) = viewModel.currencyEstimateState,
                  result.original.amount == 20
            else { return .loading }
            return .available(result)
        }
        #expect(latest.converted.amount == 2_000)

        try await Task.sleep(for: .milliseconds(175))
        let final = try await waitForAvailable { viewModel.currencyEstimateState }
        #expect(final.original.amount == 20)
        #expect(final.converted.amount == 2_000)
    }

    @Test("Tier-prefilled original amount remains authoritative")
    func tierPrefillRemainsAuthoritative() async throws {
        let preferences = try makePreferences(reportingCurrency: "RUB")
        defer { preferences.cleanUp() }
        var userPreferences = preferences.repository.load()
        userPreferences.pricingMarket = try PricingMarket(countryCode: "US")
        preferences.repository.save(userPreferences)
        let repository = RecordingRecurringItemRepository()
        let provider = StubExchangeRateProvider(responses: [.success(snapshot())])
        let tier = PlanTier(
            id: "monthly",
            name: "Monthly",
            referenceAmount: 12,
            billingCycle: .monthly,
            referenceCurrencyCode: "USD"
        )
        let template = ProviderTemplate(
            id: "test-service",
            displayName: "Test Service",
            category: .other,
            suggestedCycle: .monthly,
            suggestedCurrencyCode: "USD",
            plans: [tier]
        )
        let regionalPrice = try RegionalPlanPrice(
            key: RegionalPriceKey(
                providerPlan: template.providerPlanKey(for: tier),
                market: try PricingMarket(countryCode: "US"),
                channel: .providerDirect
            ),
            money: Money(amount: 12, currencyCode: "USD"),
            billingCycle: .monthly,
            verifiedAt: .now,
            reviewAfter: .distantFuture,
            sourceURL: try #require(URL(string: "https://example.com/pricing"))
        )
        let pricingSnapshot = try RegionalPricingSnapshot(
            schemaVersion: 1,
            revision: "test",
            prices: [regionalPrice]
        )
        let viewModel = makeAddViewModel(
            repository: repository,
            preferences: preferences.repository,
            provider: provider,
            catalog: [template],
            regionalPricingSnapshotResult: .success(pricingSnapshot)
        )

        viewModel.selectProvider(template)
        let estimate = try await waitForAvailable { viewModel.currencyEstimateState }

        #expect(viewModel.amountText == "12")
        #expect(viewModel.currencyCode == "USD")
        #expect(estimate.original.amount == 12)
        #expect(estimate.original.currencyCode == "USD")

        try await viewModel.save()
        let saved = try #require(repository.savedItems.first)
        #expect(saved.amount == 12)
        #expect(saved.currencyCode == "USD")
    }

    @Test("Converted precision is preserved and rounded only by display formatting")
    func conversionRoundsOnlyForDisplay() throws {
        let original = try Money(amount: 1, currencyCode: "EUR")
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "RUB",
            snapshot: snapshot(rubRate: 10, eurRate: 3)
        )
        let rounded = try decimal("3.33")
        let display = AmountLabel(
            result.converted.amount,
            currency: result.converted.currencyCode,
            size: .small
        ).formattedAmount

        #expect(result.converted.amount == Decimal(10) / Decimal(3))
        #expect(result.converted.amount != rounded)
        #expect(!display.contains("333333"))
    }

    @Test("RU and EN estimate freshness strings have catalog coverage")
    func estimateStringsAreLocalized() throws {
        let englishBundle = try localizationBundle("en")
        let russianBundle = try localizationBundle("ru")
        let english = Locale(identifier: "en")
        let russian = Locale(identifier: "ru")
        let date = "14 Jul 2026"

        #expect(
            String(localized: "Оценка по курсу на \(date)", bundle: englishBundle, locale: english)
                == "Estimate using rates from 14 Jul 2026"
        )
        #expect(
            String(localized: "Сохранённый курс от \(date)", bundle: englishBundle, locale: english)
                == "Cached rate from 14 Jul 2026"
        )
        #expect(
            String(localized: "Курсы валют недоступны", bundle: englishBundle, locale: english)
                == "Exchange rates unavailable"
        )

        #expect(
            String(localized: "Оценка по курсу на \(date)", bundle: russianBundle, locale: russian)
                == "Оценка по курсу на 14 Jul 2026"
        )
        #expect(
            String(localized: "Сохранённый курс от \(date)", bundle: russianBundle, locale: russian)
                == "Сохранённый курс от 14 Jul 2026"
        )
        #expect(
            String(localized: "Курсы валют недоступны", bundle: russianBundle, locale: russian)
                == "Курсы валют недоступны"
        )
    }
}
