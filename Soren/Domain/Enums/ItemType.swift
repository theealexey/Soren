import Foundation

/// The nature of a recurring payment item.
/// Determines UI presentation, billing logic, and catalog matching.
enum ItemType: String, Codable, CaseIterable, Sendable {
    /// Classic SaaS subscription: Netflix, Spotify, iCloud.
    case subscription

    /// Marketplace/ecosystem membership: Ozon Premium, WB Клуб.
    case membership

    /// Mobile carrier plan: МТС, Билайн, T2.
    case mobilePlan

    /// Home utility: internet, electricity, ЖКХ.
    case utilityBill

    /// Bundle combining multiple services: Яндекс Плюс, СберПрайм+.
    case ecosystemBundle

    /// Free trial period that converts to paid.
    case trial

    /// Anything else recurring: gym, VPN, software license.
    case otherRecurring
}

extension ItemType {
    var displayName: String {
        switch self {
        case .subscription:     String(localized: "Подписка")
        case .membership:       String(localized: "Членство")
        case .mobilePlan:       String(localized: "Тариф")
        case .utilityBill:      String(localized: "ЖКХ / Услуги")
        case .ecosystemBundle:  String(localized: "Экосистема")
        case .trial:            String(localized: "Пробный период")
        case .otherRecurring:   String(localized: "Прочее")
        }
    }

    var systemIconName: String {
        switch self {
        case .subscription:     "sparkles"
        case .membership:       "person.badge.shield.checkmark.fill"
        case .mobilePlan:       "antenna.radiowaves.left.and.right"
        case .utilityBill:      "house.fill"
        case .ecosystemBundle:  "square.stack.3d.up.fill"
        case .trial:            "hourglass"
        case .otherRecurring:   "arrow.trianglehead.2.clockwise"
        }
    }
}
