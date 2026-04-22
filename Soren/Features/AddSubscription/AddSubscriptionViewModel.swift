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
    var currencyCode: String
    var billingCycle: BillingCycle = .monthly {
        didSet {
            if !isNextChargeDateManuallySet {
                nextChargeDate = Self.suggestNextChargeDate(from: startDate, cycle: billingCycle)
            }
            recomputeEndDateIfNeeded()
        }
    }
    var category: ItemCategory = .other
    var itemType: ItemType = .subscription

    var startDate = Date.now {
        didSet {
            guard !isNextChargeDateManuallySet else { return }
            nextChargeDate = Self.suggestNextChargeDate(from: startDate, cycle: billingCycle)
        }
    }
    var nextChargeDate = Date.now {
        didSet { recomputeEndDateIfNeeded() }
    }
    private(set) var isNextChargeDateManuallySet = false

    // MARK: - Lifecycle State

    /// When true (default) the subscription renews indefinitely.
    /// When switched to false, endDate is auto-filled if the user has not yet set one manually.
    var autoRenew: Bool = true {
        didSet { recomputeEndDateIfNeeded() }
    }

    /// Proposed end date for finite subscriptions. Ignored when autoRenew is true.
    /// Auto-filled to nextChargeDate + 1 cycle when autoRenew is first set to false.
    var endDate: Date = .now

    /// True once the user explicitly picks an end date from the sheet.
    /// Prevents billingCycle / nextChargeDate changes from silently overwriting it.
    private(set) var isEndDateManuallySet = false

    var note = ""
    var usageStatus: UsageStatus = .unknown
    var chargeReminder: ChargeReminderOption = .threeDaysBefore

    // MARK: - Save State

    private(set) var saveError: Error?
    private(set) var isSaved = false

    // MARK: - Dependencies

    private let catalog: any ProviderCatalogRepository
    private let saveRecurringItem: SaveRecurringItem
    private let exchangeRateProvider: any ExchangeRateProvider
    private let preferences: UserPreferencesRepository
    private let notificationScheduler: (any NotificationScheduling)?

    // MARK: - Init

    init(
        catalog: any ProviderCatalogRepository,
        saveRecurringItem: SaveRecurringItem,
        exchangeRateProvider: any ExchangeRateProvider = StaticExchangeRateProvider(),
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.catalog = catalog
        self.saveRecurringItem = saveRecurringItem
        self.exchangeRateProvider = exchangeRateProvider
        self.preferences = preferences
        self.notificationScheduler = notificationScheduler
        self.currencyCode = preferences.load().defaultCurrencyCode
        // didSet observers don't fire during init — seed the suggestion explicitly.
        self.nextChargeDate = Self.suggestNextChargeDate(from: .now, cycle: .monthly)
    }

    init(container: AppContainer) {
        self.catalog = container.providerCatalog
        self.saveRecurringItem = SaveRecurringItem(repository: container.repositories.recurringItems)
        self.exchangeRateProvider = container.exchangeRateProvider
        self.preferences = container.preferences
        self.notificationScheduler = container.notificationScheduler
        self.currencyCode = container.preferences.load().defaultCurrencyCode
        // didSet observers don't fire during init — seed the suggestion explicitly.
        self.nextChargeDate = Self.suggestNextChargeDate(from: .now, cycle: .monthly)
    }

    // MARK: - End Date

    /// Called by the end-date binding in the form view to record a user-chosen date.
    /// Once called, auto-fill stops updating endDate for changes to cycle or charge date.
    func setEndDateManually(_ date: Date) {
        endDate = date
        isEndDateManuallySet = true
    }

    /// Recomputes endDate from the current nextChargeDate and billingCycle.
    /// Only runs when autoRenew is off and the user has not manually chosen a date.
    private func recomputeEndDateIfNeeded() {
        guard !autoRenew, !isEndDateManuallySet else { return }
        endDate = billingCycle.nextDate(after: nextChargeDate)
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
        isNextChargeDateManuallySet = false   // let billingCycle.didSet re-suggest below
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
        isNextChargeDateManuallySet = false    // let billingCycle.didSet re-suggest below
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
        currencyCode = preferences.load().defaultCurrencyCode
        billingCycle = .monthly
        category = .other
        itemType = .subscription
        isNextChargeDateManuallySet = false
        startDate = .now
        isEndDateManuallySet = false
        autoRenew = true
        endDate = .now
        note = ""
        usageStatus = .unknown
        chargeReminder = .threeDaysBefore
    }

    // MARK: - Next Charge Date

    func setNextChargeDateManually(_ date: Date) {
        nextChargeDate = date
        isNextChargeDateManuallySet = true
    }

    func resetNextChargeToAutomatic() {
        isNextChargeDateManuallySet = false
        nextChargeDate = Self.suggestNextChargeDate(from: startDate, cycle: billingCycle)
    }

    /// Suggests the next charge date for the Add form.
    ///
    /// Contract:
    /// - If `startDate` is in the future, the first charge hasn't happened yet —
    ///   return `startDate` unchanged.
    /// - Otherwise, advance by `cycle` repeatedly until the candidate is strictly
    ///   after `today`, giving the upcoming occurrence for a subscription that
    ///   started in the past or exactly on today.
    ///
    /// Pure / referentially transparent — never mutates ViewModel state.
    nonisolated static func suggestNextChargeDate(
        from startDate: Date,
        cycle: BillingCycle,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        guard startDate <= today else { return startDate }
        var candidate = startDate
        repeat {
            candidate = cycle.nextDate(after: candidate, calendar: calendar)
        } while candidate <= today
        return candidate
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
        // Mirror R2: end date must not precede the next charge date.
        // The use-case will also enforce this, but disabling Save early gives immediate feedback.
        if !autoRenew {
            guard endDate >= nextChargeDate else { return false }
        }
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
            autoRenew: autoRenew,
            endDate: autoRenew ? nil : endDate,
            chargeReminder: chargeReminder,
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

        // Schedule a charge reminder for the newly saved item.
        // Fire-and-forget: notification scheduling is best-effort and must never
        // surface an error to the user or block the save flow.
        if let scheduler = notificationScheduler {
            Task { await scheduler.schedule(for: item) }
        }
    }
}
