import Foundation

/// A complete reporting-currency projection of recurring charges scheduled
/// inside the calendar month containing the supplied calculation date.
///
/// This is a schedule plan, not payment history or confirmation that a charge
/// has been collected.
struct MonthlySubscriptionPlan: Equatable, Sendable {
    let plannedTotal: Money
    let chargeCount: Int
    let remainingTotal: Money
    let remainingChargeCount: Int
}

struct ScheduledChargeOccurrence: Equatable, Hashable, Sendable {
    let itemID: UUID
    let date: Date
}

struct SubscriptionStatusCounts: Equatable, Sendable {
    let active: Int
    let trial: Int
    let paused: Int
}

struct CurrentMonthSubscriptionPlanSnapshot: Equatable, Sendable {
    /// Nil when complete monetary aggregation is unavailable; dates and counts remain truthful.
    let plan: MonthlySubscriptionPlan?
    let scheduledCharges: [ScheduledChargeOccurrence]
    let statusCounts: SubscriptionStatusCounts
}
