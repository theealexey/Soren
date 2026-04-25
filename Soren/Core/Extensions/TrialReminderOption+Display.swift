import Foundation

// MARK: - TrialReminderOption Display

/// Presentation-layer extension mapping trial reminder options to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension TrialReminderOption {

    /// Localized label shown in Pickers and detail rows.
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
