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
    var title = ""
    var amountText = ""
    var currencyCode = "RUB"
    var billingCycle: BillingCycle = .monthly
    var category: ItemCategory = .other
    var itemType: ItemType = .subscription
    var startDate = Date.now
    var nextChargeDate = Date.now
    var note = ""

    // MARK: - Save State

    private(set) var saveError: Error?
    private(set) var isSaved = false

    // MARK: - Dependencies

    private let catalog: any ProviderCatalogRepository
    private let saveRecurringItem: SaveRecurringItem

    // MARK: - Init

    init(catalog: any ProviderCatalogRepository, saveRecurringItem: SaveRecurringItem) {
        self.catalog = catalog
        self.saveRecurringItem = saveRecurringItem
    }

    init(container: AppContainer) {
        self.catalog = container.providerCatalog
        self.saveRecurringItem = SaveRecurringItem(repository: container.repositories.recurringItems)
    }

    // MARK: - Load Providers

    func loadProviders() async {
        guard !isProvidersLoaded else { return }
        allProviders = await catalog.fetchAll()
        isProvidersLoaded = true
    }

    // MARK: - Provider Selection

    func selectProvider(_ provider: ProviderTemplate) {
        selectedProvider = provider
        title = provider.displayName
        currencyCode = provider.suggestedCurrencyCode
        billingCycle = provider.suggestedCycle
        category = provider.category
        itemType = provider.itemType
    }

    func startManualEntry() {
        selectedProvider = nil
        title = ""
        amountText = ""
        currencyCode = "RUB"
        billingCycle = .monthly
        category = .other
        itemType = .subscription
        startDate = .now
        nextChargeDate = .now
        note = ""
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
        guard !trimmed.isEmpty else { return false }
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else { return false }
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
