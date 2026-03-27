import SwiftData
import Foundation

/// Persistent storage model for a reminder rule.
@Model
final class SDReminderRule {

    @Attribute(.unique) var id: UUID
    var recurringItemID: UUID
    var triggerRaw: String    // JSON-encoded ReminderRule.Trigger
    var isEnabled: Bool

    var item: SDRecurringItem?

    init(
        id: UUID,
        recurringItemID: UUID,
        triggerRaw: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.recurringItemID = recurringItemID
        self.triggerRaw = triggerRaw
        self.isEnabled = isEnabled
    }
}
