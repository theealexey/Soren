import Foundation

/// How actively the user uses a recurring item.
/// Used in Analytics "waste" detection and insight generation.
enum UsageStatus: String, Codable, CaseIterable, Sendable {
    /// Used regularly.
    case frequentlyUsed

    /// Used sometimes.
    case occasionallyUsed

    /// Not used in a long time — potential waste.
    case unused

    /// User hasn't set this yet.
    case unknown
}

extension UsageStatus {
    var displayName: String {
        switch self {
        case .frequentlyUsed:   "Использую часто"
        case .occasionallyUsed: "Использую иногда"
        case .unused:           "Не использую"
        case .unknown:          "Не указано"
        }
    }

    /// Whether this status should trigger a "consider cancelling" insight.
    var isWasteCandidate: Bool {
        self == .unused
    }
}
