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
    var amountText = "" {
        didSet {
            if oldValue != amountText { scheduleCurrencyEstimate() }
        }
    }
    var currencyCode: String {
        didSet {
            if oldValue != currencyCode { scheduleCurrencyEstimate() }
        }
    }
    private(set) var reportingCurrencyCode: String
    private(set) var currencyEstimateState: CurrencyEstimateState = .hidden
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
    /// Seeded from `UserPreferences.defaultChargeReminder` at init time.
    /// The user can override it per-subscription in the form before saving.
    var chargeReminder: ChargeReminderOption
    /// Always `.never` in the Add flow — no trialEndDate field exists here yet,
    /// so the trial reminder picker is permanently hidden (showsTrialReminder: false).
    var trialReminder: TrialReminderOption = .never

    // MARK: - Save State

    private(set) var saveError: Error?
    private(set) var isSaved = false

    /// Localized message for the most recent save failure, mapped through
    /// ValidationErrorFormatter.  Returns nil for non-validation errors —
    /// the alert title already communicates that something went wrong.
    var saveErrorMessage: String? {
        guard let error = saveError else { return nil }
        if let ve = error as? SaveRecurringItem.ValidationError {
            return ValidationErrorFormatter.localizedMessage(for: ve)
        }
        return nil
    }

    // MARK: - Dependencies

    private let catalog: any ProviderCatalogRepository
    private let saveRecurringItem: SaveRecurringItem
    private let currencyEstimateService: CurrencyEstimateService
    private let preferences: UserPreferencesRepository
    private var estimateTask: Task<Void, Never>?
    private var currentEstimateRequest: CurrencyEstimateRequest?

    // MARK: - Init

    init(
        catalog: any ProviderCatalogRepository,
        saveRecurringItem: SaveRecurringItem,
        currencyEstimateService: CurrencyEstimateService = .preview,
        preferences: UserPreferencesRepository = UserPreferencesRepository()
    ) {
        self.catalog = catalog
        self.saveRecurringItem = saveRecurringItem
        self.currencyEstimateService = currencyEstimateService
        self.preferences = preferences
        let prefs = preferences.load()
        self.currencyCode   = prefs.defaultCurrencyCode
        self.reportingCurrencyCode = prefs.defaultCurrencyCode
        self.chargeReminder = prefs.defaultChargeReminder
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
        // A zero amount means no reliable default price exists for this tier
        // (e.g. Meta Verified — regional / platform-variable pricing).
        // Clear the field so the user sees an empty input and knows to fill it in,
        // rather than seeing "0" with a silently disabled Save button.
        amountText = tier.referencePrice.amount == 0 ? "" : tier.referencePrice.amount.description
        isNextChargeDateManuallySet = false    // let billingCycle.didSet re-suggest below
        billingCycle = tier.billingCycle
        if let override = tier.referencePrice.currencyCode {
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
        chargeReminder = preferences.load().defaultChargeReminder
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

    /// Suggests the next charge date for the Add and Edit forms.
    ///
    /// Contract:
    /// - If `startDate`'s calendar day is after today's calendar day, the first charge
    ///   hasn't happened yet — return `startDate` unchanged.
    /// - Otherwise, advance by `cycle` at least once (so startDate itself is never
    ///   returned as the "next" charge) and keep advancing while the candidate's
    ///   calendar day is still before today's calendar day. Today counts as a
    ///   valid next-charge day.
    ///
    /// Examples (cycle = monthly, today = Apr 24):
    ///   startDate Apr 24 → May 24   (started today; next bill is one cycle later)
    ///   startDate Mar 24 → Apr 24   (one cycle in the past; next bill is today)
    ///   startDate Feb 24 → Apr 24   (two cycles in the past; skip Mar, land on Apr)
    ///
    /// Day-granular comparison is load-bearing. `DatePicker` writes dates at 00:00
    /// while `today = .now` captures the current wall-clock moment. A raw `<`
    /// comparison on the full Date treats `Apr 24 00:00 < Apr 24 15:00` as true
    /// and advances one cycle too many — reproducing the on-device bug where
    /// changing startDate to Mar 24 still yielded May 24 instead of Apr 24.
    /// Normalizing both sides through `calendar.startOfDay(for:)` pins the
    /// comparison to calendar days regardless of the current hour.
    ///
    /// Pure / referentially transparent — never mutates ViewModel state.
    nonisolated static func suggestNextChargeDate(
        from startDate: Date,
        cycle: BillingCycle,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let startDay = calendar.startOfDay(for: startDate)
        let todayDay = calendar.startOfDay(for: today)
        guard startDay <= todayDay else { return startDate }
        var candidate = startDate
        repeat {
            candidate = cycle.nextDate(after: candidate, calendar: calendar)
        } while calendar.startOfDay(for: candidate) < todayDay
        return candidate
    }

    // MARK: - Derived Currency Estimate

    /// Reloads the user's reporting currency without changing the subscription currency.
    /// Called when the form appears so a Settings change made before presentation is reflected.
    func refreshReportingCurrency() {
        let latestCode = preferences.load().defaultCurrencyCode
        if latestCode != reportingCurrencyCode {
            reportingCurrencyCode = latestCode
            currentEstimateRequest = nil
        }
        scheduleCurrencyEstimate()
    }

    func cancelCurrencyEstimate() {
        estimateTask?.cancel()
        estimateTask = nil
        currentEstimateRequest = nil
        currencyEstimateState = .hidden
    }

    private func scheduleCurrencyEstimate() {
        guard
            let amount = parsedAmount,
            amount > 0,
            let request = try? CurrencyEstimateRequest(
                amount: amount,
                originalCurrencyCode: currencyCode,
                targetCurrencyCode: reportingCurrencyCode
            ),
            request.requiresConversion
        else {
            cancelCurrencyEstimate()
            return
        }

        guard request != currentEstimateRequest else { return }

        estimateTask?.cancel()
        currentEstimateRequest = request
        currencyEstimateState = .loading

        let service = currencyEstimateService
        estimateTask = Task { [weak self] in
            let state: CurrencyEstimateState
            do {
                state = .available(try await service.estimate(request))
            } catch {
                state = .unavailable
            }

            guard !Task.isCancelled else { return }
            guard let self, self.currentEstimateRequest == request else { return }
            self.currencyEstimateState = state
            self.estimateTask = nil
        }
    }

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
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
            trialReminder: trialReminder,
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
