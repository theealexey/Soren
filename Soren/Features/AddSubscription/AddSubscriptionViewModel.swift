import Foundation

// MARK: - Add Subscription View Model

/// Drives the full Add Subscription flow: provider picker → form → save.
/// Shared across both steps so state carries over seamlessly.
@MainActor @Observable
final class AddSubscriptionViewModel {

    // MARK: - Provider Picker State

    var searchText = ""

    private(set) var allProviders: [ProviderTemplate] = []
    private(set) var isProvidersLoaded = false

    // MARK: - Form State

    var selectedProvider: ProviderTemplate?
    var selectedTier: PlanTier?
    var title = ""
    var amountText = ""
    var currencyCode = "RUB"
    var billingCycle: BillingCycle = .monthly
    var category: ItemCategory = .other
    var itemType: ItemType = .subscription
    var startDate = Date.now
    var nextChargeDate = Date.now
    var note = ""
    var usageStatus: UsageStatus = .unknown

    // MARK: - Save State

    private(set) var saveError: Error?
    private(set) var isSaved = false

    // MARK: - Dependencies

    private let catalog: any ProviderCatalogRepository
    private let saveRecurringItem: SaveRecurringItem
    private let exchangeRateProvider: any ExchangeRateProvider

    // MARK: - Init

    init(catalog: any ProviderCatalogRepository, saveRecurringItem: SaveRecurringItem, exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider()) {
        self.catalog = catalog
        self.saveRecurringItem = saveRecurringItem
        self.exchangeRateProvider = exchangeRateProvider
    }

    init(container: AppContainer) {
        self.catalog = container.providerCatalog
        self.saveRecurringItem = SaveRecurringItem(repository: container.repositories.recurringItems)
        self.exchangeRateProvider = container.exchangeRateProvider
    }

    // MARK: - Load Providers

    func loadProviders() async {
        guard !isProvidersLoaded else { return }
        allProviders = await catalog.fetchAll()
        isProvidersLoaded = true
    }

    // MARK: - Provider Selection

    var availableTiers: [PlanTier] {
        selectedProvider?.plans ?? []
    }

    func selectProvider(_ provider: ProviderTemplate) {
        selectedProvider = provider
        selectedTier = nil
        title = provider.displayName
        currencyCode = provider.suggestedCurrencyCode
        billingCycle = provider.suggestedCycle
        category = provider.category
        itemType = provider.itemType

        if provider.plans.count == 1 {
            selectTier(provider.plans[0])
        } else if provider.hasPlanTiers {
            amountText = ""
        }
    }

    func selectTier(_ tier: PlanTier) {
        selectedTier = tier
        amountText = tier.amount.description   // .description is locale-independent unlike "\(decimal)"
        billingCycle = tier.billingCycle
        if let override = tier.currencyCode {
            currencyCode = override
        }
    }

    func clearTier() {
        selectedTier = nil
        amountText = ""
        if let provider = selectedProvider {
            billingCycle = provider.suggestedCycle
            currencyCode = provider.suggestedCurrencyCode
        }
    }

    func startManualEntry() {
        selectedProvider = nil
        selectedTier = nil
        title = ""
        amountText = ""
        currencyCode = "RUB"
        billingCycle = .monthly
        category = .other
        itemType = .subscription
        startDate = .now
        nextChargeDate = .now
        note = ""
        usageStatus = .unknown
    }

    // MARK: - Currency Conversion

    func convertAmount(from sourceCurrency: String, to targetCurrency: String) async {
        guard sourceCurrency != targetCurrency else { return }
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else { return }

        do {
            let rates = try await exchangeRateProvider.latestRates()
            guard let converted = rates.convert(amount, from: sourceCurrency, to: targetCurrency) else { return }
            var result = Decimal()
            var source = converted
            NSDecimalRound(&result, &source, 2, .plain)
            amountText = result.description
        } catch {
            // Rates unavailable — leave amount as-is.
        }
    }

    // MARK: - Filtered Providers

    var filteredProviders: [ProviderTemplate] {
        guard !searchText.isEmpty else { return allProviders }
        return allProviders.filter { $0.matches(searchText) }
    }

    var popularProviders: [ProviderTemplate] {
        allProviders.filter { $0.tags.contains("popular") }
    }

    var providersByCategory: [(category: ItemCategory, providers: [ProviderTemplate])] {
        let source = searchText.isEmpty ? allProviders : filteredProviders
        let grouped = Dictionary(grouping: source, by: \.category)
        return ItemCategory.allCases.compactMap { cat in
            guard let providers = grouped[cat], !providers.isEmpty else { return nil }
            return (category: cat, providers: providers)
        }
    }

    // MARK: - Validation

    var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 255 else { return false }
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0, amount < 1_000_000_000 else { return false }
        return true
    }

    // MARK: - Save

    func save() throws {
        saveError = nil

        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else {
            throw SaveRecurringItem.ValidationError.invalidAmount
        }

        let item = RecurringItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            providerID: selectedProvider?.id,
            providerName: selectedProvider?.displayName ?? title,
            itemType: itemType,
            category: category,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            startDate: startDate,
            nextChargeDate: nextChargeDate,
            status: .active,
            usageStatus: usageStatus,
            note: note
        )

        do {
            try saveRecurringItem.execute(item)
            isSaved = true
        } catch {
            saveError = error
            throw error
        }
    }
}
