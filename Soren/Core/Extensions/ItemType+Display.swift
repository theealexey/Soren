import Foundation

// MARK: - ItemType Display

/// Presentation-layer extension mapping item types to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension ItemType {

    /// Localized label shown in Pickers and detail rows.
    var displayName: String {
        switch self {
        case .subscription:    String(localized: "Подписка")
        case .membership:      String(localized: "Членство")
        case .mobilePlan:      String(localized: "Тариф")
        case .utilityBill:     String(localized: "ЖКХ / Услуги")
        case .ecosystemBundle: String(localized: "Экосистема")
        case .trial:           String(localized: "Пробный период")
        case .otherRecurring:  String(localized: "Прочее")
        }
    }
}
