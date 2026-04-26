import Foundation

// MARK: - ReminderRule.Trigger Display

/// Presentation-layer extension mapping reminder triggers to localized display strings.
/// Keeps the Domain layer free of String(localized:) and language-specific grammar.
///
/// Plural forms for day-count strings are defined in Localizable.xcstrings
/// ("За %lld дней до списания", "За %lld дней до конца пробного") using CLDR
/// plural rules — the runtime selects one/few/many/other automatically.
extension ReminderRule.Trigger {

    var displayName: String {
        switch self {
        case .daysBefore(let d):
            String(localized: "За \(d) дней до списания")
        case .onChargeDay:
            String(localized: "В день списания")
        case .onTrialEnd:
            String(localized: "При завершении пробного периода")
        case .daysBeforeTrialEnd(let d):
            String(localized: "За \(d) дней до конца пробного")
        case .onAnnualRenewal:
            String(localized: "Перед годовым продлением")
        case .onPaymentFailure:
            String(localized: "При ошибке оплаты")
        }
    }
}
