import Foundation

// MARK: - Use Case: Update Recurring Item

/// Validates and persists changes to an existing recurring item.
@MainActor
struct UpdateRecurringItem {

    private let repository: any RecurringItemRepository
    private let notificationScheduler: (any NotificationScheduling)?

    init(
        repository: any RecurringItemRepository,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    /// Normalizes, validates, stamps `updatedAt`, persists, and reschedules the notification.
    ///
    /// The scheduler's `schedule(for:)` handles all eligibility cases internally —
    /// it cancels the existing notification for paused, archived, cancelled, or
    /// `.never`-reminder items, so no branching by status is needed here.
    ///
    /// Returns the saved copy with `updatedAt` set to the current time.
    @discardableResult
    func execute(_ item: RecurringItem) async throws -> RecurringItem {
        var normalized = normalize(item)
        try validate(normalized)
        normalized.updatedAt = .now
        try repository.update(normalized)
        if let scheduler = notificationScheduler {
            await scheduler.schedule(for: normalized)
        }
        return normalized
    }

    // MARK: - Write-time normalization

    /// Clears `endDate` when `autoRenew == true`.
    /// Must run before validation so the invariant checks operate on final persisted state.
    private func normalize(_ item: RecurringItem) -> RecurringItem {
        guard item.autoRenew else { return item }
        var result = item
        result.endDate = nil
        return result
    }

    // MARK: - Validation

    private func validate(_ item: RecurringItem) throws {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty {
            throw ValidationError.emptyTitle
        }
        if item.amount <= 0 {
            throw ValidationError.invalidAmount
        }
        // R1 — finite subscription must have an end date
        if !item.autoRenew && item.endDate == nil {
            throw ValidationError.missingEndDate
        }
        // R2 — end date must not precede the next scheduled charge
        if let end = item.endDate, end < item.nextChargeDate {
            throw ValidationError.endDateBeforeNextCharge
        }
        // R3 — end date must not precede the start date
        if let end = item.endDate, item.startDate > end {
            throw ValidationError.startDateAfterEndDate
        }
    }
}

// MARK: - Validation Error

extension UpdateRecurringItem {
    enum ValidationError: LocalizedError {
        case emptyTitle
        case invalidAmount
        /// R1: autoRenew == false but no end date supplied.
        case missingEndDate
        /// R2: end date is earlier than the next scheduled charge.
        case endDateBeforeNextCharge
        /// R3: start date is later than the end date.
        case startDateAfterEndDate

        var errorDescription: String? {
            switch self {
            case .emptyTitle:
                String(localized: "Укажите название подписки")
            case .invalidAmount:
                String(localized: "Сумма должна быть больше нуля")
            case .missingEndDate:
                String(localized: "Укажите дату окончания подписки")
            case .endDateBeforeNextCharge:
                String(localized: "Дата окончания не может быть раньше следующего списания")
            case .startDateAfterEndDate:
                String(localized: "Дата начала не может быть позже даты окончания")
            }
        }
    }
}
