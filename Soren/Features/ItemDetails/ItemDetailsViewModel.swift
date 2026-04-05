import Foundation
import SwiftUI

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
    var editBillingCycle: BillingCycle = .monthly
    var editCategory: ItemCategory = .other
    var editItemType: ItemType = .subscription
    var editStartDate = Date.now
    var editNextChargeDate = Date.now
    var editNote = ""
    var editUsageStatus: UsageStatus = .unknown

    // MARK: - Dependencies

    private let updateRecurringItem: UpdateRecurringItem
    private let deleteRecurringItem: DeleteRecurringItem
    private let exchangeRateProvider: any ExchangeRateProvider

    // MARK: - Init

    init(item: RecurringItem, repositories: RepositoryContainer, exchangeRateProvider: any ExchangeRateProvider) {
        self.item = item
        self.updateRecurringItem = UpdateRecurringItem(repository: repositories.recurringItems)
        self.deleteRecurringItem = DeleteRecurringItem(repository: repositories.recurringItems)
        self.exchangeRateProvider = exchangeRateProvider
    }

    // MARK: - Edit Actions

    func startEditing() {
        editTitle = item.title
        editAmountText = item.amount.description   // locale-independent decimal string
        editCurrencyCode = item.currencyCode
        editBillingCycle = item.billingCycle
        editCategory = item.category
        editItemType = item.itemType
        editStartDate = item.startDate
        editNextChargeDate = item.nextChargeDate
        editNote = item.note
        editUsageStatus = item.usageStatus
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
        updated.note = editNote
        updated.usageStatus = editUsageStatus

        // Use the returned copy — it carries the updatedAt stamp set by the use case.
        item = try updateRecurringItem.execute(updated)
        isEditing = false
    }

    // MARK: - Status Actions

    func togglePause() throws {
        var updated = item
        updated.status = item.status == .paused ? .active : .paused
        item = try updateRecurringItem.execute(updated)
    }

    func archive() throws {
        var updated = item
        updated.status = .archived
        updated.archivedAt = .now
        item = try updateRecurringItem.execute(updated)
    }

    func delete() throws {
        try deleteRecurringItem.execute(id: item.id)
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
        return true
    }

    var cycleLabel: AmountLabel.CycleLabel {
        RecurringItemFormatter.cycleLabel(for: item.billingCycle)
    }

    var badge: SorenListRow.Badge? {
        RecurringItemFormatter.badge(for: item)
    }

    var formattedNextCharge: String {
        item.nextChargeDate.formatted(.dateTime.day().month(.wide))
    }

    var formattedStartDate: String {
        item.startDate.formatted(.dateTime.day().month(.wide).year())
    }

    var statusColor: Color {
        switch item.status {
        case .active:               ColorTokens.success
        case .dueSoon, .dueToday:   ColorTokens.warning
        case .overdue, .failed:     ColorTokens.error
        case .trial:                ColorTokens.info
        case .paused:               ColorTokens.textTertiary
        case .cancelled, .archived: ColorTokens.textTertiary
        }
    }

    var statusIcon: String {
        switch item.status {
        case .active:    "checkmark.circle.fill"
        case .dueSoon:   "clock.fill"
        case .dueToday:  "exclamationmark.circle.fill"
        case .overdue:   "exclamationmark.triangle.fill"
        case .trial:     "clock.badge.checkmark.fill"
        case .failed:    "xmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        case .paused:    "pause.circle.fill"
        case .archived:  "archivebox.fill"
        }
    }
}
