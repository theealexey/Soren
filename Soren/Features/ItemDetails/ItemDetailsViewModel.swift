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

    // MARK: - Dependencies

    private let updateRecurringItem: UpdateRecurringItem
    private let deleteRecurringItem: DeleteRecurringItem

    // MARK: - Init

    init(item: RecurringItem, repositories: RepositoryContainer) {
        self.item = item
        self.updateRecurringItem = UpdateRecurringItem(repository: repositories.recurringItems)
        self.deleteRecurringItem = DeleteRecurringItem(repository: repositories.recurringItems)
    }

    // MARK: - Edit Actions

    func startEditing() {
        editTitle = item.title
        editAmountText = "\(item.amount)"
        editCurrencyCode = item.currencyCode
        editBillingCycle = item.billingCycle
        editCategory = item.category
        editItemType = item.itemType
        editStartDate = item.startDate
        editNextChargeDate = item.nextChargeDate
        editNote = item.note
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

        try updateRecurringItem.execute(updated)
        item = updated
        item.updatedAt = .now
        isEditing = false
    }

    // MARK: - Status Actions

    func togglePause() throws {
        var updated = item
        updated.status = item.status == .paused ? .active : .paused
        try updateRecurringItem.execute(updated)
        item = updated
        item.updatedAt = .now
    }

    func archive() throws {
        var updated = item
        updated.status = .archived
        updated.archivedAt = .now
        try updateRecurringItem.execute(updated)
        item = updated
        item.updatedAt = .now
    }

    func delete() throws {
        try deleteRecurringItem.execute(id: item.id)
        isDeleted = true
    }

    // MARK: - Computed

    var canSave: Bool {
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else { return false }
        return true
    }

    var cycleLabel: AmountLabel.CycleLabel {
        HomeViewModel.cycleLabel(for: item.billingCycle)
    }

    var badge: SorenListRow.Badge? {
        HomeViewModel.badge(for: item)
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
