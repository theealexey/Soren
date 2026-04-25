import Foundation

// MARK: - Validation Error Formatter

/// Maps typed validation errors from the UseCase layer to user-facing localized
/// strings.  This is the single authoritative place where validation error copy
/// is resolved — never inside the error type itself, never inline in a View or
/// ViewModel.
///
/// Keys are resolved at call time via Localizable.xcstrings so locale changes
/// and future translations are picked up automatically.
enum ValidationErrorFormatter {

    // MARK: - Save

    static func localizedMessage(for error: SaveRecurringItem.ValidationError) -> String {
        switch error {
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

    // MARK: - Update

    static func localizedMessage(for error: UpdateRecurringItem.ValidationError) -> String {
        switch error {
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
