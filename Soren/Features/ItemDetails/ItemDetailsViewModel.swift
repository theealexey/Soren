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
    var editAmountText = ""
    var editCurrencyCode = "RUB"
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
    private let exchangeRateProvider: any ExchangeRateProvider

    // MARK: - Init

    init(
        item: RecurringItem,
        repositories: RepositoryContainer,
        exchangeRateProvider: any ExchangeRateProvider,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.item = item
        self.updateRecurringItem = UpdateRecurringItem(
            repository: repositories.recurringItems,
            notificationScheduler: notificationScheduler
        )
        self.deleteRecurringItem = DeleteRecurringItem(
            repository: repositories.recurringItems,
            notificationScheduler: notificationScheduler
        )
        self.exchangeRateProvider = exchangeRateProvider
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
    }

    func cancelEditing() {
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
        // The use case also reschedules the notification directly after a successful persist.
        item = try await updateRecurringItem.execute(updated)
        isEditing = false
    }

    // MARK: - Status Actions

    func togglePause() async throws {
        var updated = item
        updated.status = item.status == .paused ? .active : .paused
        // The scheduler handles eligibility: it cancels for paused items, reschedules for active.
        item = try await updateRecurringItem.execute(updated)
    }

    func archive() async throws {
        var updated = item
        updated.status = .archived
        updated.archivedAt = .now
        // The scheduler cancels automatically because archived items are ineligible.
        item = try await updateRecurringItem.execute(updated)
    }

    func delete() async throws {
        try await deleteRecurringItem.execute(id: item.id)
        isDeleted = true
    }

    // MARK: - Currency Conversion

    /// Called when the user changes currency in the edit form.
    /// Converts editAmountText from the old currency to the new one using cached rates.
    /// Silently no-ops if rates are unavailable — leaves the amount unchanged.
    func convertAmount(from sourceCurrency: String, to targetCurrency: String) async {
        guard sourceCurrency != targetCurrency else { return }
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")) else { return }

        do {
            let rates = try await exchangeRateProvider.latestRates()
            guard let converted = rates.convert(amount, from: sourceCurrency, to: targetCurrency) else { return }
            var result = Decimal()
            var source = converted
            NSDecimalRound(&result, &source, 2, .plain)
            editAmountText = result.description
        } catch {
            // Rates unavailable — leave amount as-is, don't break the form.
        }
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
        item.nextChargeDate.formatted(.dateTime.day().month(.wide))
    }

    var formattedStartDate: String {
        item.startDate.formatted(.dateTime.day().month(.wide).year())
    }
}
