import Foundation

// MARK: - Resolve Regional Plan Price

/// Canonical synchronous policy for resolving a native price suggestion.
/// Resolution requires an exact provider-plan, market and purchase-channel key;
/// it never falls back across markets and never invokes currency conversion.
struct ResolveRegionalPlanPriceUseCase: Sendable {
    func execute(
        key: RegionalPriceKey,
        snapshot: RegionalPricingSnapshot,
        asOf date: Date
    ) -> RegionalPriceResolution {
        guard snapshot.containsPrices(in: key.market) else {
            return .unavailable(.marketNotSupported)
        }

        guard let price = snapshot.price(for: key) else {
            return .unavailable(.priceNotFound)
        }

        guard date <= price.reviewAfter else {
            return .requiresReview(price)
        }

        return .available(price)
    }
}
