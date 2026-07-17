import Foundation

// MARK: - Billing Landscape Point

/// Presentation-preserving result for one day of financial aggregation.
/// A missing conversion remains unavailable; it is never represented as zero.
enum DailyFinancialState: Equatable {
    case complete(amount: Decimal)
    case partial(amount: Decimal, missingCurrencyCodes: [String])
    case unavailable(
        missingCurrencyCodes: [String],
        reason: SpendAggregationUnavailableReason
    )

    init(aggregationResult: RecurringSpendAggregationResult) {
        switch aggregationResult {
        case let .complete(total, _):
            self = .complete(amount: total.amount)
        case let .partial(total, missingCurrencyCodes, _):
            self = .partial(amount: total.amount, missingCurrencyCodes: missingCurrencyCodes)
        case let .unavailable(_, missingCurrencyCodes, reason, _):
            self = .unavailable(
                missingCurrencyCodes: missingCurrencyCodes,
                reason: reason
            )
        }
    }

    var numericAmount: Decimal? {
        switch self {
        case let .complete(amount), let .partial(amount, _):
            amount
        case .unavailable:
            nil
        }
    }
}

/// One calendar day's billing weight within the 30-day landscape.
/// `id` is the day offset (0-based) — stable within a displayed month,
/// enabling predictable SwiftUI diffing across data reloads.
struct BillingLandscapePoint: Identifiable {

    /// Day offset from the start of the displayed window. 0 = today.
    let id: Int

    let date: Date

    /// Typed aggregation state. This is the source of truth for available versus
    /// unavailable financial values.
    let financialState: DailyFinancialState

    /// 0.0–1.0 for available values; nil when this day cannot be converted.
    let normalizedHeight: Double?

    let currencyCode: String
    let chargeCount: Int

    /// Available numeric amount only. Kept as a convenience for numeric consumers;
    /// unavailable conversions have no amount rather than a fabricated zero.
    var rawTotal: Decimal? { financialState.numericAmount }
}
