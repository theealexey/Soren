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

    }
}
