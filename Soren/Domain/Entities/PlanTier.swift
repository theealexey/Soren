import Foundation

// MARK: - Plan Tier

/// A specific pricing tier within a service provider's offerings.
/// For example, Netflix has Standard ($15.49/mo) and Premium ($22.99/mo).
struct PlanTier: Identifiable, Hashable, Sendable {
    /// Unique identifier within the provider, e.g. "standard", "family".
    let id: String

    /// Display name, e.g. "Premium", "Семейный".
    var name: String

    /// Price for this tier.
    var amount: Decimal

    /// Billing frequency for this tier.
    var billingCycle: BillingCycle

    /// Currency override. `nil` means inherit from the provider's `suggestedCurrencyCode`.
    var currencyCode: String?

    /// Optional one-liner describing what's included, e.g. "4K HDR, 4 экрана".
    var features: String?
}
