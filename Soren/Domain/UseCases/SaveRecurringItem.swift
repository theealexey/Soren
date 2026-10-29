import Foundation

// MARK: - Use Case: Save Recurring Item

/// Validates and persists a new recurring item.
///
struct SaveRecurringItemResult: Sendable, Equatable {
    let item: RecurringItem
    let notificationOutcome: NotificationRefreshOutcome?
}

/// Notification reconciliation is deliberately non-transactional: persistence
/// remains authoritative, while the returned outcome keeps any later
/// notification failure observable to the caller.
@MainActor
struct SaveRecurringItem {

    private let repository: any RecurringItemRepository
    private let notificationCoordinator: (any NotificationStateReconciling)?

    init(
        repository: any RecurringItemRepository,
        notificationCoordinator: (any NotificationStateReconciling)? = nil
    ) {
        self.repository = repository
        self.notificationCoordinator = notificationCoordinator
    }

    @discardableResult
    func execute(_ item: RecurringItem) async throws -> SaveRecurringItemResult {
        try item.billingCycle.validate()
        let normalized = normalize(item)
        try validate(normalized)
        try item.validateCanonicalBillingDates()
        try item.validateRenewalDecision()
        try repository.save(normalized)
        let outcome = await notificationCoordinator?.reconcileCurrentState(source: .create)
        return SaveRecurringItemResult(item: normalized, notificationOutcome: outcome)
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

extension SaveRecurringItem {
    /// Typed validation failures.  Localized user-facing messages are produced
    /// by ValidationErrorFormatter in the presentation layer — not here.
    enum ValidationError: Error {
        case emptyTitle
        case invalidAmount
        /// R1: autoRenew == false but no end date supplied.
        case missingEndDate
        /// R2: end date is earlier than the next scheduled charge.
        case endDateBeforeNextCharge
        /// R3: start date is later than the end date.
        case startDateAfterEndDate
    }
}
