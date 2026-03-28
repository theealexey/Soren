import Foundation

/// A notification rule attached to a recurring item.
/// Decoupled from UNNotification — the Notification scheduler maps this to system calls.
struct ReminderRule: Identifiable, Hashable, Sendable {
    let id: UUID
    let recurringItemID: UUID
    var trigger: Trigger
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        recurringItemID: UUID,
        trigger: Trigger,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.recurringItemID = recurringItemID
        self.trigger = trigger
        self.isEnabled = isEnabled
    }
}

extension ReminderRule {
    enum Trigger: Codable, Hashable, Sendable {
        case daysBefore(Int)   // e.g. 1, 3, 7 days before next charge
        case onChargeDay
        case onTrialEnd
        case daysBeforeTrialEnd(Int)
        case onAnnualRenewal
        case onPaymentFailure

        var displayName: String {
            switch self {
            case .daysBefore(let d):        String(localized: "За \(d) \(dayWord(d)) до списания")
            case .onChargeDay:              String(localized: "В день списания")
            case .onTrialEnd:               String(localized: "При завершении пробного периода")
            case .daysBeforeTrialEnd(let d): String(localized: "За \(d) \(dayWord(d)) до конца пробного")
            case .onAnnualRenewal:          String(localized: "Перед годовым продлением")
            case .onPaymentFailure:         String(localized: "При ошибке оплаты")
            }
        }

        private func dayWord(_ days: Int) -> String {
            switch days % 10 {
            case 1 where days % 100 != 11: "день"
            case 2...4 where !(days % 100 >= 12 && days % 100 <= 14): "дня"
            default: "дней"
            }
        }
    }
}
