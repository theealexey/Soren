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
        case .weekly:       String(localized: "Еженедельно")
        case .monthly:      String(localized: "Ежемесячно")
        case .quarterly:    String(localized: "Раз в квартал")
        case .semiannual:   String(localized: "Раз в полгода")
        case .annual:       String(localized: "Ежегодно")
        case .custom(let d): String(localized: "Каждые \(d) дн.")
        }
    }

    var shortName: String {
        switch self {
        case .weekly:       String(localized: "нед")
        case .monthly:      String(localized: "мес")
        case .quarterly:    String(localized: "кв")
        case .semiannual:   String(localized: "п/г")
        case .annual:       String(localized: "год")
        case .custom(let d): String(localized: "\(d)д")
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
    /// All literals use Decimal(string:) to avoid Double intermediate representation (binary imprecision).
    var monthlyMultiplier: Decimal {
        switch self {
        case .weekly:           Decimal(string: "4.333")!   // 52 weeks / 12 months
        case .monthly:          Decimal(1)
        case .quarterly:        Decimal(string: "0.3333")!  // 1/3
        case .semiannual:       Decimal(string: "0.1667")!  // 1/6
        case .annual:           Decimal(string: "0.0833")!  // 1/12
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
    /// `.custom` is intentionally excluded — it requires a companion days-input UI
    /// and cannot be represented as a simple Picker row. Use a dedicated custom-days editor instead.
    static var allCases: [BillingCycle] {
        [.weekly, .monthly, .quarterly, .semiannual, .annual]
    }
}
