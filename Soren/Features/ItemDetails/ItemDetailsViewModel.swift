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
        didSet { recomputeEditEndDateIfNeeded() }
    }
    var editCategory: ItemCategory = .other
    var editItemType: ItemType = .subscription
    var editStartDate = Date.now
    var editNextChargeDate = Date.now {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    var editNote = ""
    var editUsageStatus: UsageStatus = .unknown

    // MARK: - Edit Lifecycle Fields

    var editAutoRenew: Bool = true {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    var editEndDate: Date = .now
    private(set) var isEditEndDateManuallySet = false

    var editChargeReminder: ChargeReminderOption = .threeDaysBefore

    // MARK: - Dependencies

    private let updateRecurringItem: UpdateRecurringItem
    private let deleteRecurringItem: DeleteRecurringItem
    private let exchangeRateProvider: any ExchangeRateProvider
    private let notificationScheduler: (any NotificationScheduling)?

    // MARK: - Init

    init(
        item: RecurringItem,
        repositories: RepositoryContainer,
        exchangeRateProvider: any ExchangeRateProvider,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.item = item
        self.updateRecurringItem = UpdateRecurringItem(repository: repositories.recurringItems)
        self.deleteRecurringItem = DeleteRecurringItem(repository: repositories.recurringItems)
        self.exchangeRateProvider = exchangeRateProvider
        self.notificationScheduler = notificationScheduler
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
        editStartDate = item.startDate
        editNote = item.note
        editUsageStatus = item.usageStatus
        // Lifecycle fields: set the manual-override flag before assigning cycle/date so
        // their didSet handlers don't auto-fill an endDate for existing stored values.
        isEditEndDateManuallySet = item.endDate != nil
        editBillingCycle = item.billingCycle
        editNextChargeDate = item.nextChargeDate
        // Seed endDate: use stored value, or compute a sensible default for existing
        // auto-renew items (unused unless the user switches autoRenew off).
        editEndDate = item.endDate ?? item.billingCycle.nextDate(after: item.nextChargeDate)
        editAutoRenew = item.autoRenew
        editChargeReminder = item.chargeReminder
        isEditing = true
    }

    func cancelEditing() {
        isEditing = false
    }

    func saveChanges() throws {
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
        updated.note = editNote
        updated.usageStatus = editUsageStatus

        // Use the returned copy — it carries the updatedAt stamp set by the use case.
        item = try updateRecurringItem.execute(updated)
        isEditing = false

        // Reschedule: any field that affects the fire date (title, amount, nextChargeDate,
        // billingCycle) may have changed. Cancel + re-add is the safest approach.
        if let scheduler = notificationScheduler {
            let saved = item
            Task { await scheduler.schedule(for: saved) }
        }
    }

    // MARK: - Status Actions

    func togglePause() throws {
        var updated = item
        updated.status = item.status == .paused ? .active : .paused
        item = try updateRecurringItem.execute(updated)

        if let scheduler = notificationScheduler {
            let saved = item
            Task {
                if saved.status == .paused {
                    // Paused — no further charges expected; cancel the reminder.
                    await scheduler.cancel(for: saved.id)
                } else {
                    // Resumed — treat as a newly active item and reschedule.
                    await scheduler.schedule(for: saved)
                }
            }
        }
    }

    func archive() throws {
        var updated = item
        updated.status = .archived
        updated.archivedAt = .now
        item = try updateRecurringItem.execute(updated)

        if let scheduler = notificationScheduler {
            let itemID = item.id
            Task { await scheduler.cancel(for: itemID) }
        }
    }

    func delete() throws {
        let itemID = item.id
        try deleteRecurringItem.execute(id: itemID)
        isDeleted = true

        if let scheduler = notificationScheduler {
            Task { await scheduler.cancel(for: itemID) }
        }
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
