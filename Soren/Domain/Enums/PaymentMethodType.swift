import Foundation

/// How a recurring item is paid for.
enum PaymentMethodType: String, Codable, CaseIterable, Sendable {
    case bankCard
    case appleID
    case mobileBilling   // operator direct billing
    case bankAccount
    case cash
    case unknown
}

extension PaymentMethodType {
    var displayName: String {
        switch self {
        case .bankCard:       String(localized: "Банковская карта")
        case .appleID:        "Apple ID"
        case .mobileBilling:  String(localized: "Счёт оператора")
        case .bankAccount:    String(localized: "Расчётный счёт")
        case .cash:           String(localized: "Наличные / вручную")
        case .unknown:        String(localized: "Не указан")
        }
    }

    var systemIconName: String {
        switch self {
        case .bankCard:       "creditcard.fill"
        case .appleID:        "applelogo"
        case .mobileBilling:  "iphone.radiowaves.left.and.right"
        case .bankAccount:    "building.columns.fill"
        case .cash:           "banknote.fill"
        case .unknown:        "questionmark.circle.fill"
        }
    }
}
