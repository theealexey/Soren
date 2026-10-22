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
    enum ValidationError: Error, Equatable {
        case invalidCustomDays(Int)
    }

    func validate() throws {
        if case let .custom(days) = self, days <= 0 {
            throw ValidationError.invalidCustomDays(days)
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

    /// Annual equivalent is the basis; repeating divisions retain Foundation Decimal precision.
    func annualEquivalent(for amount: Decimal) throws -> Decimal {
        try validate()
        switch self {
        case .weekly: return amount * 365 / 7
        case .monthly: return amount * 12
        case .quarterly: return amount * 4
        case .semiannual: return amount * 2
        case .annual: return amount
        case let .custom(days): return amount * 365 / Decimal(days)
        }
    }

    /// Compatibility coefficient. Item amounts normalize before division to avoid coefficient truncation.
    var monthlyMultiplier: Decimal {
        get throws {
            try annualEquivalent(for: 1) / 12
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

extension BillingCycle {
    /// Returns a date advanced by exactly one billing cycle.
    /// Uses calendar-aware arithmetic for month-based cycles so end-of-month
    /// dates stay valid (e.g. Jan 31 + 1 month = Feb 28, not an invalid date).
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .weekly:           calendar.date(byAdding: .day,   value: 7,    to: date) ?? date
        case .monthly:          calendar.date(byAdding: .month, value: 1,    to: date) ?? date
        case .quarterly:        calendar.date(byAdding: .month, value: 3,    to: date) ?? date
        case .semiannual:       calendar.date(byAdding: .month, value: 6,    to: date) ?? date
        case .annual:           calendar.date(byAdding: .year,  value: 1,    to: date) ?? date
        case .custom(let days): calendar.date(byAdding: .day,   value: days, to: date) ?? date
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
