import Foundation
import Testing
@testable import Soren

@Suite("Add Subscription — Save submission")
@MainActor
struct AddSubscriptionSaveTests {
    private enum PersistenceFailure: Error { case rejected }

    private final class Repository: RecurringItemRepository {
        private(set) var items: [RecurringItem] = []
        private(set) var saveCalls = 0
        var rejectsSave = false

        func fetchAll() throws -> [RecurringItem] { items }
        func fetchActive() throws -> [RecurringItem] { items }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { items }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { items.filter { $0.category == category } }
        func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
        func save(_ item: RecurringItem) throws {
            saveCalls += 1
            if rejectsSave { throw PersistenceFailure.rejected }
            items.append(item)
        }
        func update(_ item: RecurringItem) throws { throw PersistenceFailure.rejected }
        func delete(id: UUID) throws { throw PersistenceFailure.rejected }
        func saveAll(_ items: [RecurringItem]) throws { throw PersistenceFailure.rejected }
        func deleteAll() throws { throw PersistenceFailure.rejected }
    }

    private final class Reconciliation: NotificationStateReconciling {
        private(set) var calls = 0
        var suspends = false
        var outcome = NotificationRefreshOutcome.reconciled(NotificationReconciliationReport(
            desiredCount: 1, removedPendingCount: 0, removedDeliveredCount: 0,
            addedCount: 1, authorizationStatus: .authorized, addFailures: [], planningFailures: []
        ))
        private var pending: CheckedContinuation<NotificationRefreshOutcome, Never>?
        private var entered: CheckedContinuation<Void, Never>?

        func reconcileCurrentState(source: NotificationReconciliationSource) async -> NotificationRefreshOutcome {
            calls += 1
            guard suspends else { return outcome }
            return await withCheckedContinuation { continuation in
                pending = continuation
                entered?.resume()
                entered = nil
            }
        }

        func waitUntilSuspended() async {
            guard pending == nil else { return }
            await withCheckedContinuation { entered = $0 }
        }

        func release() {
            let continuation = pending
            pending = nil
            continuation?.resume(returning: outcome)
        }
    }

    private struct Fixture {
        let suite: String
        let defaults: UserDefaults
        let repository: Repository
        let reconciliation: Reconciliation
        let vm: AddSubscriptionViewModel
        func cleanUp() { defaults.removePersistentDomain(forName: suite) }
    }

    private func fixture() throws -> Fixture {
        let suite = "AddSubscriptionSaveTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        let preferences = UserPreferencesRepository(defaults: defaults, initialDeviceRegionCode: "RU")
        let repository = Repository()
        let reconciliation = Reconciliation()
        let today = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 21))
        let vm = AddSubscriptionViewModel(
            catalog: InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repository, notificationCoordinator: reconciliation),
            preferences: preferences, currentDate: { today }, timeZone: { .gmt }
        )
        vm.title = "Submission"
        vm.amountText = "124"
        vm.currencyCode = "RUB"
        return Fixture(suite: suite, defaults: defaults, repository: repository,
                       reconciliation: reconciliation, vm: vm)
    }

    @Test("Suspended save admits one identity and one reconciliation; saved submission stays closed")
    func suspendedSaveIsSingleFlight() async throws {
        let f = try fixture()
        defer { f.cleanUp() }
        f.reconciliation.suspends = true
        #expect(f.vm.canSave)
        #expect(f.vm.isSaving == false)
        #expect(f.vm.isSaved == false)
        let first = Task { try await f.vm.save() }
        await f.reconciliation.waitUntilSuspended()
        defer { f.reconciliation.release() }
        #expect(f.vm.isSaving)
        #expect(f.vm.isSaved == false)
        #expect(f.vm.canSave == false)
        #expect(f.repository.items.count == 1)
        #expect(f.repository.saveCalls == 1)
        #expect(try await f.vm.save() == false)
        #expect(f.vm.saveError == nil)
        #expect(f.repository.items.count == 1)
        f.reconciliation.release()
        #expect(try await first.value)
        #expect(f.vm.isSaving == false)
        #expect(f.vm.isSaved)
        #expect(f.vm.canSave == false)
        #expect(try await f.vm.save() == false)
        #expect(f.repository.saveCalls == 1)
        #expect(Set(f.repository.items.map(\.id)).count == 1)
        #expect(f.reconciliation.calls == 1)
    }

    @Test("Validation failures retain the draft, unlock submission and allow correction", arguments: [false, true])
    func validationAllowsRetry(invalidAmount: Bool) async throws {
        let f = try fixture()
        defer { f.cleanUp() }
        if invalidAmount { f.vm.amountText = "invalid" } else { f.vm.title = "" }
        #expect(f.vm.canSave == false)
        do {
            try await f.vm.save()
            Issue.record("Invalid submission unexpectedly succeeded")
        } catch SaveRecurringItem.ValidationError.invalidAmount {
            #expect(invalidAmount)
        } catch SaveRecurringItem.ValidationError.emptyTitle {
            #expect(invalidAmount == false)
        } catch {
            Issue.record("Unexpected validation error: \(error)")
        }
        #expect(f.vm.saveError is SaveRecurringItem.ValidationError)
        #expect(f.vm.isSaving == false)
        #expect(f.vm.isSaved == false)
        #expect(f.repository.items.isEmpty)
        #expect(f.repository.saveCalls == 0)
        #expect(f.reconciliation.calls == 0)
        #expect(f.vm.amountText == (invalidAmount ? "invalid" : "124"))
        f.vm.title = "Corrected"
        f.vm.amountText = "124"
        #expect(f.vm.canSave)
        #expect(try await f.vm.save())
        #expect(f.vm.saveError == nil)
        #expect(f.vm.isSaved)
        #expect(f.repository.items.count == 1)
    }

    @Test("Repository failure propagates and a corrected retry persists exactly once")
    func persistenceAllowsRetry() async throws {
        let f = try fixture()
        defer { f.cleanUp() }
        f.repository.rejectsSave = true
        await #expect(throws: PersistenceFailure.rejected) { try await f.vm.save() }
        #expect(f.vm.saveError is PersistenceFailure)
        #expect(f.vm.isSaving == false)
        #expect(f.vm.isSaved == false)
        #expect(f.vm.canSave)
        #expect(f.vm.title == "Submission")
        #expect(f.vm.amountText == "124")
        #expect(f.repository.items.isEmpty)
        #expect(f.reconciliation.calls == 0)
        f.repository.rejectsSave = false
        #expect(try await f.vm.save())
        #expect(f.vm.saveError == nil)
        #expect(f.repository.items.count == 1)
        #expect(f.repository.saveCalls == 2)
        #expect(f.reconciliation.calls == 1)
    }

    @Test("Nonfatal notification failure remains a saved submission")
    func notificationFailureDoesNotReinsert() async throws {
        let f = try fixture()
        defer { f.cleanUp() }
        f.reconciliation.outcome = .repositoryFetchFailed
        #expect(try await f.vm.save())
        #expect(f.vm.isSaved)
        #expect(f.vm.isSaving == false)
        #expect(f.vm.canSave == false)
        #expect(f.vm.saveError == nil)
        #expect(try await f.vm.save() == false)
        #expect(f.repository.items.count == 1)
        #expect(f.repository.saveCalls == 1)
        #expect(f.reconciliation.calls == 1)
    }

    @Test("Identical fields in independent Add lifetimes remain legitimate")
    func independentSubmissionsAreAllowed() async throws {
        let first = try fixture()
        let second = try fixture()
        defer { first.cleanUp(); second.cleanUp() }
        #expect(try await first.vm.save())
        #expect(try await second.vm.save())
        let a = try #require(first.repository.items.first)
        let b = try #require(second.repository.items.first)
        #expect(a.title == b.title)
        #expect(a.amount == b.amount)
        #expect(a.id != b.id)
    }
}

@Suite("Add Subscription — Regional Pricing")
@MainActor
struct AddSubscriptionTierTests {

    private let asOf = Date(timeIntervalSince1970: 1_753_000_000)
    private let afterReview = Date(timeIntervalSince1970: 1_754_000_000)

    private final class RecordingRecurringItemRepository: RecurringItemRepository {
        private(set) var savedItems: [RecurringItem] = []

        func fetchAll() throws -> [RecurringItem] { [] }
        func fetchActive() throws -> [RecurringItem] { [] }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { [] }
        func fetch(id: UUID) throws -> RecurringItem? { nil }
        func save(_ item: RecurringItem) throws { savedItems.append(item) }
        func update(_ item: RecurringItem) throws {}
        func delete(id: UUID) throws {}
        func saveAll(_ items: [RecurringItem]) throws { savedItems.append(contentsOf: items) }
        func deleteAll() throws { savedItems.removeAll() }
    }

    private struct Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let preferences: UserPreferencesRepository
        let repository: RecordingRecurringItemRepository
        let viewModel: AddSubscriptionViewModel

        func cleanUp() {
            defaults.removePersistentDomain(forName: suiteName)
        }
    }

    private func makeFixture(
        marketCode: String = "US",
        reportingCurrencyCode: String = "USD",
        result: Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> = .failure(.resourceNotFound("RegionalPricing")),
        date: Date? = nil
    ) throws -> Fixture {
        let suiteName = "AddSubscriptionTierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let preferences = UserPreferencesRepository(
            defaults: defaults,
            initialDeviceRegionCode: "US"
        )
        var values = preferences.load()
        values.defaultCurrencyCode = reportingCurrencyCode
        values.pricingMarket = try PricingMarket(countryCode: marketCode)
        preferences.save(values)

        let repository = RecordingRecurringItemRepository()
        let viewModel = AddSubscriptionViewModel(
            catalog: InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repository),
            preferences: preferences,
            regionalPricingSnapshotResult: result,
            currentDate: { date ?? self.asOf }
        )

        return Fixture(
            suiteName: suiteName,
            defaults: defaults,
            preferences: preferences,
            repository: repository,
            viewModel: viewModel
        )
    }

    private func provider(
        id: String = "test-provider",
        currency: String = "USD",
        tiers: [PlanTier]
    ) -> ProviderTemplate {
        ProviderTemplate(
            id: id,
            displayName: "Test Provider",
            category: .video,
            suggestedCycle: .monthly,
            suggestedCurrencyCode: currency,
            plans: tiers
        )
    }

    private func price(
        provider: ProviderTemplate,
        tier: PlanTier,
        marketCode: String = "US",
        amount: Decimal,
        currencyCode: String,
        billingCycle: BillingCycle,
        reviewAfter: Date? = nil
    ) throws -> RegionalPlanPrice {
        try RegionalPlanPrice(
            key: RegionalPriceKey(
                providerPlan: provider.providerPlanKey(for: tier),
                market: PricingMarket(countryCode: marketCode),
                channel: .providerDirect
            ),
            money: Money(amount: amount, currencyCode: currencyCode),
            billingCycle: billingCycle,
            verifiedAt: asOf,
            reviewAfter: reviewAfter ?? afterReview,
            sourceURL: try #require(URL(string: "https://example.com/pricing"))
        )
    }

    private func result(
        _ prices: [RegionalPlanPrice]
    ) throws -> Result<RegionalPricingSnapshot, BundledRegionalPricingLoaderError> {
        .success(try RegionalPricingSnapshot(schemaVersion: 1, revision: "test", prices: prices))
    }

    private func productionBundle() throws -> Bundle {
        if Bundle.main.bundleIdentifier == "com.alexey.soren" {
            return Bundle.main
        }

        return try #require(
            Bundle.allBundles.first { $0.bundleIdentifier == "com.alexey.soren" }
        )
    }

    @Test("Application composition loads the accepted US and RU snapshot once")
    func compositionLoadsProductionSnapshot() throws {
        let pricing = AppContainer.loadRegionalPricing(in: try productionBundle())
        let snapshot: RegionalPricingSnapshot
        switch pricing {
        case .success(let loaded):
            snapshot = loaded
        case .failure(let error):
            Issue.record("Unexpected regional pricing loading failure: \(error)")
            return
        }

        let spotifyKey = try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: "spotify", tierID: "individual"),
            market: PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let tBankKey = try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: "tbank_pro", tierID: "pro"),
            market: PricingMarket(countryCode: "RU"),
            channel: .providerDirect
        )

        #expect(snapshot.revision == "2026-07-21.1")
        #expect(snapshot.containsPrices(in: try PricingMarket(countryCode: "US")))
        #expect(snapshot.containsPrices(in: try PricingMarket(countryCode: "RU")))
        #expect(snapshot.price(for: spotifyKey)?.money.amount == 12.99)
        #expect(snapshot.price(for: tBankKey)?.money.amount == 299)
    }

    @Test("Available exact price populates native amount, currency and billing cycle")
    func availablePricePopulatesForm() throws {
        let tier = PlanTier(id: "individual", name: "Individual", referenceAmount: 99, billingCycle: .annual)
        let provider = provider(tiers: [tier])
        let fixture = try makeFixture(result: result([
            try price(provider: provider, tier: tier, amount: 12.99, currencyCode: "USD", billingCycle: .monthly)
        ]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        #expect(fixture.viewModel.selectedTier?.id == "individual")
        #expect(fixture.viewModel.amountText == "12.99")
        #expect(fixture.viewModel.currencyCode == "USD")
        #expect(fixture.viewModel.billingCycle == .monthly)
        #expect(fixture.viewModel.pricingState == .verified(try price(
            provider: provider,
            tier: tier,
            amount: 12.99,
            currencyCode: "USD",
            billingCycle: .monthly
        )))
        #expect(!fixture.viewModel.isPricingInputUserModified)
        #expect(
            fixture.viewModel.tierPricingPresentation(for: tier)
                == .verified(money: try Money(amount: 12.99, currencyCode: "USD"), billingCycle: .monthly)
        )
    }

    @Test("Production US Spotify Individual resolves 12.99 USD monthly")
    func usSpotifyIndividual() throws {
        let snapshot = try AppContainer.loadRegionalPricing(in: productionBundle()).get()
        let spotify = try #require(ProviderCatalog.template(forProviderID: "spotify"))
        let individual = try #require(spotify.plans.first { $0.id == "individual" })
        let fixture = try makeFixture(result: .success(snapshot))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(spotify)
        fixture.viewModel.selectTier(individual)

        #expect(fixture.viewModel.amountText == "12.99")
        #expect(fixture.viewModel.currencyCode == "USD")
        #expect(fixture.viewModel.billingCycle == .monthly)
    }

    @Test("Production RU T-Bank Pro resolves 299 RUB monthly")
    func ruTBankPro() throws {
        let snapshot = try AppContainer.loadRegionalPricing(in: productionBundle()).get()
        let tBank = try #require(ProviderCatalog.template(forProviderID: "tbank_pro"))
        let pro = try #require(tBank.plans.first { $0.id == "pro" })
        let fixture = try makeFixture(marketCode: "RU", reportingCurrencyCode: "USD", result: .success(snapshot))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(tBank)
        fixture.viewModel.selectTier(pro)

        #expect(fixture.viewModel.amountText == "299")
        #expect(fixture.viewModel.currencyCode == "RUB")
        #expect(fixture.viewModel.billingCycle == .monthly)
        #expect(fixture.preferences.load().defaultCurrencyCode == "USD")
    }

    @Test("Production US Apple Music Family resolves 19.99 USD monthly")
    func usAppleMusicFamily() throws {
        let snapshot = try AppContainer.loadRegionalPricing(in: productionBundle()).get()
        let appleMusic = try #require(ProviderCatalog.template(forProviderID: "apple_music"))
        let family = try #require(appleMusic.plans.first { $0.id == "family" })
        let fixture = try makeFixture(result: .success(snapshot))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(appleMusic)
        fixture.viewModel.selectTier(family)

        #expect(fixture.viewModel.amountText == "19.99")
        #expect(fixture.viewModel.currencyCode == "USD")
        #expect(fixture.viewModel.billingCycle == .monthly)
    }

    @Test("Unavailable exact key preserves typed reason and never uses reference price")
    func unavailablePriceUsesManualEntry() throws {
        let tier = PlanTier(id: "missing", name: "Missing", referenceAmount: 42, billingCycle: .annual, referenceCurrencyCode: "EUR")
        let missingProvider = provider(tiers: [tier])
        let availableTier = PlanTier(id: "available", name: "Available", referenceAmount: 1, billingCycle: .monthly)
        let availableProvider = provider(tiers: [availableTier])
        let fixture = try makeFixture(result: result([
            try price(provider: availableProvider, tier: availableTier, amount: 1, currencyCode: "USD", billingCycle: .monthly)
        ]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(missingProvider)

        #expect(fixture.viewModel.pricingState == .unavailable(.priceNotFound))
        #expect(fixture.viewModel.amountText == "")
        #expect(fixture.viewModel.currencyCode == "USD")
        #expect(fixture.viewModel.billingCycle == .monthly)
        #expect(fixture.viewModel.tierPricingPresentation(for: tier) == .manualEntry)
        #expect(!fixture.viewModel.canSave)
    }

    @Test("Unsupported synthetic market preserves marketNotSupported without cross-market fallback")
    func unsupportedMarketIsTypedUnavailable() throws {
        let tier = PlanTier(id: "basic", name: "Basic", referenceAmount: 77, billingCycle: .monthly)
        let provider = provider(tiers: [tier])
        let fixture = try makeFixture(
            marketCode: "GB",
            result: result([
                try price(provider: provider, tier: tier, marketCode: "US", amount: 12.99, currencyCode: "USD", billingCycle: .monthly)
            ])
        )
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        #expect(fixture.viewModel.pricingState == .unavailable(.marketNotSupported))
        #expect(fixture.viewModel.amountText == "")
        #expect(fixture.viewModel.tierPricingPresentation(for: tier) == .manualEntry)
    }

    @Test("Loader failure exposes manual entry and does not use CatalogReferencePrice")
    func loaderFailureUsesExplicitManualState() throws {
        let tier = PlanTier(id: "basic", name: "Basic", referenceAmount: 9.99, billingCycle: .monthly)
        let provider = provider(tiers: [tier])
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        #expect(fixture.viewModel.pricingState == .loadingUnavailable)
        #expect(fixture.viewModel.amountText == "")
        #expect(fixture.viewModel.tierPricingPresentation(for: tier) == .manualEntry)
    }

    @Test("Review boundary is verified at reviewAfter and manual after reviewAfter")
    func requiresReviewDoesNotPopulateAmount() throws {
        let tier = PlanTier(id: "annual", name: "Annual", referenceAmount: 99, billingCycle: .annual)
        let provider = provider(tiers: [tier])
        let price = try price(
            provider: provider,
            tier: tier,
            amount: 120,
            currencyCode: "USD",
            billingCycle: .annual,
            reviewAfter: afterReview
        )
        let boundary = try makeFixture(result: result([price]), date: afterReview)
        defer { boundary.cleanUp() }
        boundary.viewModel.selectProvider(provider)
        #expect(boundary.viewModel.amountText == "120")
        #expect(boundary.viewModel.pricingState == .verified(price))

        let stale = try makeFixture(result: result([price]), date: afterReview.addingTimeInterval(1))
        defer { stale.cleanUp() }
        stale.viewModel.selectProvider(provider)
        #expect(stale.viewModel.pricingState == .requiresReview(price))
        #expect(stale.viewModel.amountText == "")
        #expect(!stale.viewModel.canSave)
        #expect(stale.viewModel.tierPricingPresentation(for: tier) == .requiresReview)
    }

    @Test("Manual edits preserve final original money and do not get overwritten on market refresh")
    func userModifiedPriceWinsOverMarketRefreshAndSave() async throws {
        let tier = PlanTier(id: "individual", name: "Individual", referenceAmount: 1, billingCycle: .monthly)
        let provider = provider(tiers: [tier])
        let usPrice = try price(provider: provider, tier: tier, amount: 12.99, currencyCode: "USD", billingCycle: .monthly)
        let ruPrice = try price(provider: provider, tier: tier, marketCode: "RU", amount: 999, currencyCode: "RUB", billingCycle: .annual)
        let fixture = try makeFixture(result: result([usPrice, ruPrice]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)
        fixture.viewModel.amountText = "15.50"
        fixture.viewModel.currencyCode = "EUR"
        fixture.viewModel.billingCycle = .quarterly

        var preferences = fixture.preferences.load()
        preferences.pricingMarket = try PricingMarket(countryCode: "RU")
        fixture.preferences.save(preferences)
        fixture.viewModel.refreshPricingMarket()

        #expect(fixture.viewModel.isPricingInputUserModified)
        #expect(fixture.viewModel.pricingState == .userModified)
        #expect(fixture.viewModel.amountText == "15.50")
        #expect(fixture.viewModel.currencyCode == "EUR")
        #expect(fixture.viewModel.billingCycle == .quarterly)

        try await fixture.viewModel.save()
        let saved = try #require(fixture.repository.savedItems.first)
        #expect(saved.amount == 15.50)
        #expect(saved.currencyCode == "EUR")
        #expect(saved.billingCycle == .quarterly)
    }

    @Test("Untouched verified input re-resolves when the pricing market changes")
    func marketRefreshReplacesUntouchedVerifiedPrice() throws {
        let tier = PlanTier(id: "individual", name: "Individual", referenceAmount: 1, billingCycle: .monthly)
        let provider = provider(tiers: [tier])
        let fixture = try makeFixture(result: result([
            try price(provider: provider, tier: tier, amount: 12.99, currencyCode: "USD", billingCycle: .monthly),
            try price(provider: provider, tier: tier, marketCode: "RU", amount: 299, currencyCode: "RUB", billingCycle: .annual)
        ]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)
        var preferences = fixture.preferences.load()
        preferences.pricingMarket = try PricingMarket(countryCode: "RU")
        fixture.preferences.save(preferences)
        fixture.viewModel.refreshPricingMarket()

        #expect(!fixture.viewModel.isPricingInputUserModified)
        #expect(fixture.viewModel.amountText == "299")
        #expect(fixture.viewModel.currencyCode == "RUB")
        #expect(fixture.viewModel.billingCycle == .annual)
    }

    @Test("A deliberate new tier starts a fresh regional price resolution")
    func newTierStartsFreshResolution() throws {
        let first = PlanTier(id: "first", name: "First", referenceAmount: 1, billingCycle: .monthly)
        let second = PlanTier(id: "second", name: "Second", referenceAmount: 2, billingCycle: .monthly)
        let provider = provider(tiers: [first, second])
        let fixture = try makeFixture(result: result([
            try price(provider: provider, tier: first, amount: 10, currencyCode: "USD", billingCycle: .monthly),
            try price(provider: provider, tier: second, amount: 20, currencyCode: "USD", billingCycle: .annual)
        ]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)
        fixture.viewModel.selectTier(first)
        fixture.viewModel.amountText = "11"
        fixture.viewModel.selectTier(second)

        #expect(!fixture.viewModel.isPricingInputUserModified)
        #expect(fixture.viewModel.amountText == "20")
        #expect(fixture.viewModel.billingCycle == .annual)
    }

    @Test("Selecting and clearing a tier never falls back to its reference price")
    func selectionStructureRemainsConsistent() throws {
        let tiers = [
            PlanTier(id: "basic", name: "Basic", referenceAmount: 9.99, billingCycle: .monthly),
            PlanTier(id: "premium", name: "Premium", referenceAmount: 22.99, billingCycle: .monthly)
        ]
        let provider = provider(tiers: tiers)
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)
        #expect(fixture.viewModel.selectedTier == nil)
        #expect(fixture.viewModel.availableTiers.count == 2)

        fixture.viewModel.selectTier(tiers[1])
        #expect(fixture.viewModel.selectedTier?.id == "premium")
        #expect(fixture.viewModel.amountText == "")

        fixture.viewModel.clearTier()
        #expect(fixture.viewModel.selectedTier == nil)
        #expect(fixture.viewModel.amountText == "")
        #expect(fixture.viewModel.billingCycle == .monthly)
        #expect(fixture.viewModel.currencyCode == "USD")
    }

    @Test("Active pricing market presentation is human-readable and independent from reporting currency")
    func activePricingMarketPresentation() throws {
        let us = try makeFixture(marketCode: "US", reportingCurrencyCode: "RUB")
        defer { us.cleanUp() }
        let ru = try makeFixture(marketCode: "RU", reportingCurrencyCode: "USD")
        defer { ru.cleanUp() }
        let englishBundle = try localizationBundle("en")
        let english = Locale(identifier: "en")

        #expect(us.viewModel.pricingMarketPresentation == .unitedStates)
        #expect(ru.viewModel.pricingMarketPresentation == .russia)
        #expect(us.viewModel.reportingCurrencyCode == "RUB")
        #expect(ru.viewModel.reportingCurrencyCode == "USD")
        #expect(
            String(localized: "США", bundle: englishBundle, locale: english)
                == "United States"
        )
        #expect(
            String(localized: "Россия", bundle: englishBundle, locale: english)
                == "Russia"
        )
    }

    @Test("Verified presentation exposes exact regional quote provenance without reference-price fallback")
    func verifiedPresentationUsesRegionalQuote() throws {
        let tier = PlanTier(
            id: "individual",
            name: "Individual",
            referenceAmount: 999,
            billingCycle: .annual,
            referenceCurrencyCode: "EUR"
        )
        let provider = provider(tiers: [tier])
        let regionalPrice = try price(
            provider: provider,
            tier: tier,
            amount: 12.99,
            currencyCode: "USD",
            billingCycle: .monthly
        )
        let fixture = try makeFixture(result: result([regionalPrice]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        let expected = AddSubscriptionRegionalQuotePresentation(price: regionalPrice)
        #expect(fixture.viewModel.pricingPresentation == .verified(expected))
        #expect(expected.money.amount == 12.99)
        #expect(expected.money.currencyCode == "USD")
        #expect(expected.billingCycle == .monthly)
        #expect(expected.verifiedAt == asOf)
        #expect(expected.sourceURL == URL(string: "https://example.com/pricing"))
        #expect(expected.money.amount != tier.referencePrice.amount)
        #expect(expected.money.currencyCode != tier.referencePrice.currencyCode)
        #expect(fixture.viewModel.amountText == "12.99")
        #expect(!fixture.viewModel.isPricingInputUserModified)
    }

    @Test("Requires-review presentation preserves last-known provenance but requires manual input")
    func requiresReviewPresentationPreservesQuote() throws {
        let tier = PlanTier(
            id: "annual",
            name: "Annual",
            referenceAmount: 5,
            billingCycle: .monthly
        )
        let provider = provider(tiers: [tier])
        let regionalPrice = try price(
            provider: provider,
            tier: tier,
            amount: 120,
            currencyCode: "USD",
            billingCycle: .annual,
            reviewAfter: afterReview
        )
        let fixture = try makeFixture(
            result: result([regionalPrice]),
            date: afterReview.addingTimeInterval(1)
        )
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        let expected = AddSubscriptionRegionalQuotePresentation(price: regionalPrice)
        #expect(fixture.viewModel.pricingPresentation == .requiresReview(expected))
        #expect(expected.money.amount == 120)
        #expect(expected.money.currencyCode == "USD")
        #expect(expected.billingCycle == .annual)
        #expect(expected.verifiedAt == asOf)
        #expect(expected.sourceURL == URL(string: "https://example.com/pricing"))
        #expect(fixture.viewModel.amountText.isEmpty)
        #expect(!fixture.viewModel.canSave)
        #expect(fixture.viewModel.tierPricingPresentation(for: tier) == .requiresReview)
    }

    @Test("Typed unavailable presentation contains no quote, zero, source, or reference price")
    func unavailablePresentationRemainsManual() throws {
        let missingTier = PlanTier(
            id: "missing",
            name: "Missing",
            referenceAmount: 42,
            billingCycle: .annual,
            referenceCurrencyCode: "EUR"
        )
        let missingProvider = provider(tiers: [missingTier])
        let availableTier = PlanTier(
            id: "available",
            name: "Available",
            referenceAmount: 1,
            billingCycle: .monthly
        )
        let availableProvider = provider(tiers: [availableTier])
        let fixture = try makeFixture(result: result([
            try price(
                provider: availableProvider,
                tier: availableTier,
                amount: 10,
                currencyCode: "USD",
                billingCycle: .monthly
            )
        ]))
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(missingProvider)

        #expect(fixture.viewModel.pricingPresentation == .unavailable(.priceNotFound))
        #expect(fixture.viewModel.amountText.isEmpty)
        #expect(fixture.viewModel.amountText != "0")
        #expect(fixture.viewModel.amountText != missingTier.referencePrice.amount.description)
        #expect(fixture.viewModel.tierPricingPresentation(for: missingTier) == .manualEntry)
    }

    @Test("Loader failure remains distinct from normal price-not-found")
    func loaderFailurePresentationIsDistinct() throws {
        let tier = PlanTier(
            id: "basic",
            name: "Basic",
            referenceAmount: 9.99,
            billingCycle: .monthly
        )
        let provider = provider(tiers: [tier])
        let fixture = try makeFixture(
            result: .failure(.jsonDecodingFailed("private decoder details"))
        )
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        #expect(fixture.viewModel.pricingPresentation == .loaderFailure)
        #expect(fixture.viewModel.pricingPresentation != .unavailable(.priceNotFound))
        #expect(fixture.viewModel.amountText.isEmpty)
        #expect(fixture.viewModel.tierPricingPresentation(for: tier) == .manualEntry)
    }

    @Test("Manual amount, currency, and cycle edits each become authoritative presentation state")
    func eachPricingFieldCanBecomeUserModified() throws {
        let tier = PlanTier(
            id: "individual",
            name: "Individual",
            referenceAmount: 1,
            billingCycle: .monthly
        )
        let provider = provider(tiers: [tier])
        let regionalPrice = try price(
            provider: provider,
            tier: tier,
            amount: 12.99,
            currencyCode: "USD",
            billingCycle: .monthly
        )

        let amountFixture = try makeFixture(result: result([regionalPrice]))
        defer { amountFixture.cleanUp() }
        amountFixture.viewModel.selectProvider(provider)
        amountFixture.viewModel.amountText = "15"
        #expect(amountFixture.viewModel.pricingPresentation == .userModified)
        #expect(amountFixture.viewModel.tierPricingPresentation(for: tier) == .userModified)

        let currencyFixture = try makeFixture(result: result([regionalPrice]))
        defer { currencyFixture.cleanUp() }
        currencyFixture.viewModel.selectProvider(provider)
        currencyFixture.viewModel.currencyCode = "EUR"
        #expect(currencyFixture.viewModel.pricingPresentation == .userModified)
        #expect(currencyFixture.viewModel.amountText == "12.99")

        let cycleFixture = try makeFixture(result: result([regionalPrice]))
        defer { cycleFixture.cleanUp() }
        cycleFixture.viewModel.selectProvider(provider)
        cycleFixture.viewModel.billingCycle = .quarterly
        #expect(cycleFixture.viewModel.pricingPresentation == .userModified)
        #expect(cycleFixture.viewModel.amountText == "12.99")
    }

    @Test("Review boundary remains verified in semantic presentation")
    func reviewBoundaryPresentationIsVerified() throws {
        let tier = PlanTier(
            id: "boundary",
            name: "Boundary",
            referenceAmount: 1,
            billingCycle: .monthly
        )
        let provider = provider(tiers: [tier])
        let regionalPrice = try price(
            provider: provider,
            tier: tier,
            amount: 10,
            currencyCode: "USD",
            billingCycle: .monthly,
            reviewAfter: afterReview
        )
        let fixture = try makeFixture(
            result: result([regionalPrice]),
            date: afterReview
        )
        defer { fixture.cleanUp() }

        fixture.viewModel.selectProvider(provider)

        #expect(
            fixture.viewModel.pricingPresentation
                == .verified(AddSubscriptionRegionalQuotePresentation(price: regionalPrice))
        )
        #expect(fixture.viewModel.amountText == "10")
    }

    private func localizationBundle(_ languageCode: String) throws -> Bundle {
        let appBundle = try #require(Bundle(identifier: "com.alexey.soren"))
        let path = try #require(appBundle.path(forResource: languageCode, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }
}
