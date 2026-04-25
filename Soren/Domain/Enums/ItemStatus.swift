import Foundation

/// Lifecycle state of a recurring item.
enum ItemStatus: String, Codable, CaseIterable, Sendable {
    /// Active and up to date.
    case active

    /// Next charge within 7 days.
    case dueSoon

    /// Charges today.
    case dueToday

    /// Past due — charge not recorded.
    case overdue

    /// Active trial period.
    case trial

    /// Last payment failed.
    case failed

    /// User cancelled — tracking for reference.
    case cancelled

    /// Temporarily paused by user.
    case paused

    /// Archived — not counted in totals.
    case archived
}

extension ItemStatus {
    /// Whether this item contributes to monthly/yearly totals.
    var countsInTotals: Bool {
        switch self {
        case .active, .dueSoon, .dueToday, .overdue, .trial, .failed:
            true
        case .cancelled, .paused, .archived:
            false
        }
    }

    /// Whether this item should surface alerts.
    var requiresAttention: Bool {
        switch self {
        case .dueSoon, .dueToday, .overdue, .trial, .failed:
            true
        default:
            false
        }
    }
}
