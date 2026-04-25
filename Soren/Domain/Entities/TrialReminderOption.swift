import Foundation

// MARK: - Trial Reminder Option

/// Per-subscription setting controlling when the trial-ending reminder fires.
///
/// Stored as a `String` rawValue so future cases can be added without
/// breaking existing SwiftData records. Default is `.never` — users opt in.
enum TrialReminderOption: String, CaseIterable, Codable, Sendable {
    case never           = "never"
    case sameDay         = "sameDay"
    case oneDayBefore    = "oneDayBefore"
    case threeDaysBefore = "threeDaysBefore"
    case sevenDaysBefore = "sevenDaysBefore"

    /// Days before the trial-end date to fire the notification.
    /// `nil` means the user chose "Never" — no notification should be scheduled.
    var alertDays: Int? {
        switch self {
        case .never:           nil
        case .sameDay:         0
        case .oneDayBefore:    1
        case .threeDaysBefore: 3
        case .sevenDaysBefore: 7
        }
    }

}
