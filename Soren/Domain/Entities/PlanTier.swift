import Foundation

// MARK: - Plan Tier

/// Legacy catalog reference data used to prefill existing selection flows.
/// It is not a verified, market-aware regional price and must never be used
/// as input to Regional Pricing resolution.
struct CatalogReferencePrice: Hashable, Sendable {
    let amount: Decimal
    let currencyCode: String?

    init(amount: Decimal, currencyCode: String? = nil) {
        self.amount = amount
        self.currencyCode = currencyCode
    }
}

/// A specific tier within a service provider's offerings.
/// Its legacy reference price remains available for current catalog UI only.
struct PlanTier: Identifiable, Hashable, Sendable {
    /// Unique identifier within the provider, e.g. "standard", "family".
    let id: String

    /// Display name, e.g. "Premium", "Семейный".
    var name: String

    /// Legacy, non-authoritative catalog reference data for current UI prefill.
    var referencePrice: CatalogReferencePrice

    /// Billing frequency for this tier.
    var billingCycle: BillingCycle

    /// Optional one-liner describing what's included, e.g. "4K HDR, 4 экрана".
    var features: String?

    init(
        id: String,
        name: String,
        referenceAmount: Decimal,
        billingCycle: BillingCycle,
        referenceCurrencyCode: String? = nil,
        features: String? = nil
    ) {
        self.id = id
        self.name = name
        self.referencePrice = CatalogReferencePrice(
            amount: referenceAmount,
            currencyCode: referenceCurrencyCode
        )
        self.billingCycle = billingCycle
        self.features = features
    }
}
