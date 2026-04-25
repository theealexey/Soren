import Testing
@testable import Soren

// MARK: - Validation Error Formatter Tests

/// Verifies that every typed validation case maps to a non-empty localized string.
/// Exact wording is intentionally NOT asserted — copy changes should not break tests.
@Suite("ValidationErrorFormatter")
struct ValidationErrorFormatterTests {

    // MARK: - SaveRecurringItem errors

    @Test func saveEmptyTitleIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .emptyTitle as SaveRecurringItem.ValidationError).isEmpty)
    }

    @Test func saveInvalidAmountIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .invalidAmount as SaveRecurringItem.ValidationError).isEmpty)
    }

    @Test func saveMissingEndDateIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .missingEndDate as SaveRecurringItem.ValidationError).isEmpty)
    }

    @Test func saveEndDateBeforeNextChargeIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .endDateBeforeNextCharge as SaveRecurringItem.ValidationError).isEmpty)
    }

    @Test func saveStartDateAfterEndDateIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .startDateAfterEndDate as SaveRecurringItem.ValidationError).isEmpty)
    }

    // MARK: - UpdateRecurringItem errors

    @Test func updateEmptyTitleIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .emptyTitle as UpdateRecurringItem.ValidationError).isEmpty)
    }

    @Test func updateInvalidAmountIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .invalidAmount as UpdateRecurringItem.ValidationError).isEmpty)
    }

    @Test func updateMissingEndDateIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .missingEndDate as UpdateRecurringItem.ValidationError).isEmpty)
    }

    @Test func updateEndDateBeforeNextChargeIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .endDateBeforeNextCharge as UpdateRecurringItem.ValidationError).isEmpty)
    }

    @Test func updateStartDateAfterEndDateIsNonEmpty() {
        #expect(!ValidationErrorFormatter.localizedMessage(for: .startDateAfterEndDate as UpdateRecurringItem.ValidationError).isEmpty)
    }
}
