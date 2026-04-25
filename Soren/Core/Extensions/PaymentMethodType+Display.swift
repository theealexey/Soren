import Foundation

// MARK: - PaymentMethodType Display

/// Presentation-layer extension mapping payment method types to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension PaymentMethodType {

    /// Localized label shown in Pickers and detail rows.
    var displayName: String {
        switch self {
        case .bankCard:      String(localized: "Банковская карта")
        case .appleID:       "Apple ID"
        case .mobileBilling: String(localized: "Счёт оператора")
        case .bankAccount:   String(localized: "Расчётный счёт")
        case .cash:          String(localized: "Наличные / вручную")
        case .unknown:       String(localized: "Не указан")
        }
    }
}
