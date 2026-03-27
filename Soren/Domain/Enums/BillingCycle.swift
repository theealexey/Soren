import Foundation

/// How often a recurring item charges.
enum BillingCycle: Codable, Hashable, Sendable {
    case weekly
    case monthly
    case quarterly       // every 3 months
    case semiannual      // every 6 months
    case annual
    case custom(days: Int)
}

extension BillingCycle {
    var displayName: String {
        switch self {
        case .weekly:       "Еженедельно"
        case .monthly:      "Ежемесячно"
        case .quarterly:    "Раз в квартал"
        case .semiannual:   "Раз в полгода"
        case .annual:       "Ежегодно"
        case .custom(let d): "Каждые \(d) дн."
        }
    }

    var shortName: String {
        switch self {
        case .weekly:       "нед"
        case .monthly:      "мес"
        case .quarterly:    "кв"
        case .semiannual:   "п/г"
        case .annual:       "год"
        case .custom(let d): "\(d)д"
        }
    }

    /// Approximate number of days in one cycle.
    var approximateDays: Int {
        switch self {
        case .weekly:           7
        case .monthly:          30
        case .quarterly:        91
        case .semiannual:       182
        case .annual:           365
        case .custom(let d):    d
        }
    }

    /// Monthly equivalent cost multiplier.
    /// Used to normalise costs in Analytics.
    var monthlyMultiplier: Decimal {
        switch self {
        case .weekly:           4.33
        case .monthly:          1
        case .quarterly:        0.333
        case .semiannual:       0.166
        case .annual:           0.0833
        case .custom(let d):    Decimal(30) / Decimal(d)
        }
    }

    /// True for billing cycles longer than a month — used to flag annual renewals.
    var isLongCycle: Bool {
        switch self {
        case .quarterly, .semiannual, .annual: true
        default: false
        }
    }
}

extension BillingCycle: CaseIterable {
    static var allCases: [BillingCycle] {
        [.weekly, .monthly, .quarterly, .semiannual, .annual]
    }
}
