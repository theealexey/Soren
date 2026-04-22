import Foundation

// MARK: - Charge Reminder Option

/// Per-subscription setting controlling when the charge-reminder notification fires.
///
/// Stored as a `String` rawValue so future cases can be added without
/// breaking existing SwiftData records (unknown values fall back to `.threeDaysBefore`).
enum ChargeReminderOption: String, CaseIterable, Codable, Sendable {
    case never           = "never"
    case sameDay         = "sameDay"
    case oneDayBefore    = "oneDayBefore"
    case threeDaysBefore = "threeDaysBefore"
    case sevenDaysBefore = "sevenDaysBefore"

    /// Days before the charge date to fire the notification.
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

    var displayName: String {
        switch self {
        case .never:           String(localized: "Никогда")
        case .sameDay:         String(localized: "В день списания")
        case .oneDayBefore:    String(localized: "За 1 день")
        case .threeDaysBefore: String(localized: "За 3 дня")
        case .sevenDaysBefore: String(localized: "За 7 дней")
        }
    }
}
