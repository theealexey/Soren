import Foundation

// MARK: - UsageStatus Display

/// Presentation-layer extension mapping usage states to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension UsageStatus {

    /// Localized label shown in Pickers and detail rows.
    var displayName: String {
        switch self {
        case .frequentlyUsed:   String(localized: "Использую часто")
        case .occasionallyUsed: String(localized: "Использую иногда")
        case .unused:           String(localized: "Не использую")
        case .unknown:          String(localized: "Не указано")
        }
    }
}
