import Foundation

// MARK: - Item Details View Model

/// Drives the Item Details screen: display, edit, status changes, and deletion.
@MainActor @Observable
final class ItemDetailsViewModel {

    // MARK: - Display State

    var item: RecurringItem
    var isEditing = false
    var showDeleteConfirmation = false
    private(set) var isDeleted = false

    // MARK: - Edit Form Fields

    var editTitle = ""
    var editAmountText = "" {
        didSet {
            if oldValue != editAmountText { scheduleCurrencyEstimate() }
        }
    }
    var editCurrencyCode = "RUB" {
        didSet {
            if oldValue != editCurrencyCode { scheduleCurrencyEstimate() }
        }
    }
    private(set) var reportingCurrencyCode: String
    private(set) var currencyEstimateState: CurrencyEstimateState = .hidden
    var editBillingCycle: BillingCycle = .monthly {
        didSet {
            if !isEditNextChargeDateManuallySet {
                editNextChargeDate = AddSubscriptionViewModel.suggestNextChargeDate(
                    from: editStartDate, cycle: editBillingCycle
                )
            }
            recomputeEditEndDateIfNeeded()
        }
    }
    var editCategory: ItemCategory = .other
    var editItemType: ItemType = .subscription
    var editStartDate = Date.now {
        didSet {
            guard !isEditNextChargeDateManuallySet else { return }
            editNextChargeDate = AddSubscriptionViewModel.suggestNextChargeDate(
                from: editStartDate, cycle: editBillingCycle
            )
        }
    }
    var editNextChargeDate = Date.now {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    /// True once the user explicitly picks a next-charge date from the edit form,
    /// or once `startEditing()` seeds the form from a stored item (the stored value
    /// is treated as manually committed so cycle/startDate changes don't clobber it
    /// on first load). Reset via `resetEditNextChargeToAutomatic()` if we ever add
    /// that affordance.
    private(set) var isEditNextChargeDateManuallySet = false
    var editNote = ""
    var editUsageStatus: UsageStatus = .unknown

    // MARK: - Edit Lifecycle Fields

    var editAutoRenew: Bool = true {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    var editEndDate: Date = .now
    private(set) var isEditEndDateManuallySet = false

    var editChargeReminder: ChargeReminderOption = .threeDaysBefore
    var editTrialReminder: TrialReminderOption = .never

    // MARK: - Dependencies

    private let updateRecurringItem: UpdateRecurringItem
    private let deleteRecurringItem: DeleteRecurringItem
    private let currencyEstimateService: CurrencyEstimateService
    private let preferences: UserPreferencesRepository
    private var estimateTask: Task<Void, Never>?
    private var currentEstimateRequest: CurrencyEstimateRequest?

    // MARK: - Init

    init<Provider: ExchangeRateProvider>(
        item: RecurringItem,
        repositories: RepositoryContainer,
        exchangeRateProvider: Provider,
        notificationCoordinator: (any NotificationStateReconciling)? = nil,
        convertMoney: ConvertMoneyUseCase = ConvertMoneyUseCase(),
        preferences: UserPreferencesRepository = UserPreferencesRepository()
    ) {
        self.item = item
        self.updateRecurringItem = UpdateRecurringItem(
            repository: repositories.recurringItems,
            notificationCoordinator: notificationCoordinator
        )
        self.deleteRecurringItem = DeleteRecurringItem(
            repository: repositories.recurringItems,
            notificationCoordinator: notificationCoordinator
        )
        self.currencyEstimateService = CurrencyEstimateService(
            exchangeRateProvider: exchangeRateProvider,
            convertMoney: convertMoney
        )
        self.preferences = preferences
        self.reportingCurrencyCode = preferences.load().defaultCurrencyCode
    }

    init(
        item: RecurringItem,
        updateRecurringItem: UpdateRecurringItem,
        deleteRecurringItem: DeleteRecurringItem,
        currencyEstimateService: CurrencyEstimateService,
        preferences: UserPreferencesRepository
    ) {
        self.item = item
        self.updateRecurringItem = updateRecurringItem
        self.deleteRecurringItem = deleteRecurringItem
        self.currencyEstimateService = currencyEstimateService
        self.preferences = preferences
        self.reportingCurrencyCode = preferences.load().defaultCurrencyCode
    }

    // MARK: - Edit Next Charge Date

    /// Called by the next-charge-date binding in the edit form to record a user-chosen date.
    /// Once called, auto-fill stops updating editNextChargeDate for changes to cycle or startDate.
    func setEditNextChargeDateManually(_ date: Date) {
        editNextChargeDate = date
        isEditNextChargeDateManuallySet = true
    }

    // MARK: - Edit End Date

    func setEditEndDateManually(_ date: Date) {
        editEndDate = date
        isEditEndDateManuallySet = true
    }

    private func recomputeEditEndDateIfNeeded() {
        guard !editAutoRenew, !isEditEndDateManuallySet else { return }
        editEndDate = editBillingCycle.nextDate(after: editNextChargeDate)
    }

    // MARK: - Edit Actions

    func startEditing() {
        editTitle = item.title
        editAmountText = item.amount.description   // locale-independent decimal string
        editCurrencyCode = item.currencyCode
        editCategory = item.category
        editItemType = item.itemType
        editNote = item.note
        editUsageStatus = item.usageStatus
        // Lifecycle fields: set the manual-override flag before assigning cycle/date so
        // their didSet handlers don't auto-fill endDate/nextChargeDate for existing stored
        // values. Stored nextChargeDate is treated as manually committed — otherwise
        // assigning editStartDate / editBillingCycle below would auto-suggest a new
        // nextChargeDate and silently overwrite the user's persisted date on form open.
        isEditEndDateManuallySet = item.endDate != nil
        isEditNextChargeDateManuallySet = true
        editStartDate = item.startDate
        editBillingCycle = item.billingCycle
        editNextChargeDate = item.nextChargeDate
        // Seed endDate: use stored value, or compute a sensible default for existing
        // auto-renew items (unused unless the user switches autoRenew off).
        editEndDate = item.endDate ?? item.billingCycle.nextDate(after: item.nextChargeDate)
        editAutoRenew = item.autoRenew
        // Release the manual-override flag now that seed is complete. Subsequent
        // startDate / billingCycle changes made by the user in this session will
        // auto-recompute nextChargeDate — until the user explicitly picks one via
        // the date binding, at which point setEditNextChargeDateManually re-locks it.
        isEditNextChargeDateManuallySet = false
        editChargeReminder = item.chargeReminder
        editTrialReminder  = item.trialReminder
        isEditing = true
        refreshReportingCurrency()
    }

    func cancelEditing() {
        cancelCurrencyEstimate()
        isEditing = false
    }

    func saveChanges() async throws {
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")) else {
            throw UpdateRecurringItem.ValidationError.invalidAmount
        }

        var updated = item
        updated.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.amount = amount
        updated.currencyCode = editCurrencyCode
        updated.billingCycle = editBillingCycle
        updated.category = editCategory
        updated.itemType = editItemType
        updated.startDate = editStartDate
        updated.nextChargeDate = editNextChargeDate
        updated.autoRenew = editAutoRenew
        updated.endDate = editAutoRenew ? nil : editEndDate
        updated.chargeReminder = editChargeReminder
        updated.trialReminder  = editTrialReminder
        updated.note = editNote
        updated.usageStatus = editUsageStatus

        // Use the returned copy — it carries the updatedAt stamp set by the use case.
        // Notification work is a complete reconciliation after persistence.
        item = try await updateRecurringItem.execute(updated).item
        cancelCurrencyEstimate()
        isEditing = false
    }

    // MARK: - Status Actions

    func togglePause() async throws {
        var updated = item
        updated.status = item.status == .paused ? .active : .paused
        // Eligibility is evaluated from the complete persisted state.
        item = try await updateRecurringItem.execute(updated).item
    }

    func archive() async throws {
        var updated = item
        updated.status = .archived
        updated.archivedAt = .now
        item = try await updateRecurringItem.execute(updated).item
    }

    func delete() async throws {
        _ = try await deleteRecurringItem.execute(id: item.id)
        isDeleted = true
    }

    // MARK: - Derived Currency Estimate

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
        guard isEditing else { return }
        guard
            let amount = parsedEditAmount,
            amount > 0,
            let request = try? CurrencyEstimateRequest(
                amount: amount,
                originalCurrencyCode: editCurrencyCode,
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

    private var parsedEditAmount: Decimal? {
        Decimal(string: editAmountText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Computed

    var canSave: Bool {
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 255 else { return false }
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0, amount < 1_000_000_000 else { return false }
        if !editAutoRenew {
            guard editEndDate >= editNextChargeDate else { return false }
        }
        return true
    }

    var formattedNextCharge: String {
        item.nextChargeDate.formatted(
            .dateTime
                .day()
                .month(.wide)
                .locale(PresentationLocale.current)
        )
    }

    var formattedStartDate: String {
        item.startDate.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
                .locale(PresentationLocale.current)
        )
    }
}
