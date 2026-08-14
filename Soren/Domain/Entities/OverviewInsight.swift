import Foundation

/// One deterministic, presentation-agnostic insight selected for Overview.
enum OverviewInsight: Equatable, Sendable {
    case attention(Attention)
    case denseWeek(DenseWeek)
    case annualScale(Money)
}

extension OverviewInsight {
    enum Attention: Equatable, Sendable {
        case trialEnding(TrialEnding)
        case sameDayRenewals(SameDayRenewals)
    }

    struct TrialEnding: Equatable, Sendable {
        let itemID: UUID
        let itemTitle: String
        let trialEndDate: Date
        let renewalTerms: RenewalTerms?
    }

    /// Paid terms are present only when the persisted trial data proves the
    /// amount and cycle of the charge occurring when the trial ends.
    struct RenewalTerms: Equatable, Sendable {
        let amount: Money
        let billingCycle: BillingCycle
    }

    struct SameDayRenewals: Equatable, Sendable {
        let chargeDate: Date
        let itemIDs: [UUID]
        let total: Money?

        var chargeCount: Int { itemIDs.count }
    }

    struct DenseWeek: Equatable, Sendable {
        let firstChargeDate: Date
        let lastChargeDate: Date
        let itemIDs: [UUID]
        let total: Money?

        var chargeCount: Int { itemIDs.count }
    }
}
