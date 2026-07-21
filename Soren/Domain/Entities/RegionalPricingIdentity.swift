import Foundation

// MARK: - Regional Pricing Identity

enum PricingMarketValidationError: Error, Equatable, Sendable {
    case invalidCountryCode(String)
}

/// An ISO 3166-1 alpha-2 market used to resolve a provider's native price.
/// This is intentionally distinct from `ProviderTemplate.Region`, which groups
/// catalog availability rather than a purchaser's billing market.
struct PricingMarket: Hashable, Sendable {
    let countryCode: String

    init(countryCode: String) throws {
        let normalized = countryCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let bytes = normalized.utf8
        let isTwoUppercaseASCIILetters = bytes.count == 2
            && bytes.allSatisfy { (65...90).contains($0) }

        guard isTwoUppercaseASCIILetters else {
            throw PricingMarketValidationError.invalidCountryCode(countryCode)
        }

        self.countryCode = normalized
    }
}

/// The purchase surface whose price is being represented.
/// A provider-direct price is never assumed to be equivalent to an App Store price.
enum PricingChannel: String, Hashable, Sendable {
    case providerDirect
    case appleAppStore
}

enum ProviderPlanKeyValidationError: Error, Equatable, Sendable {
    case emptyProviderID
    case emptyTierID
}

/// Stable catalog identity for one provider plan.
/// Provider and tier IDs are intentionally kept as distinct canonical values:
/// a tier ID is unique only within its provider.
struct ProviderPlanKey: Hashable, Sendable {
    let providerID: String
    let tierID: String

    init(providerID: String, tierID: String) throws {
        let normalizedProviderID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTierID = tierID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedProviderID.isEmpty else {
            throw ProviderPlanKeyValidationError.emptyProviderID
        }
        guard !normalizedTierID.isEmpty else {
            throw ProviderPlanKeyValidationError.emptyTierID
        }

        self.providerID = normalizedProviderID
        self.tierID = normalizedTierID
    }
}

/// Full lookup key for a regional recurring-price suggestion.
struct RegionalPriceKey: Hashable, Sendable {
    let providerPlan: ProviderPlanKey
    let market: PricingMarket
    let channel: PricingChannel

    init(
        providerPlan: ProviderPlanKey,
        market: PricingMarket,
        channel: PricingChannel
    ) {
        self.providerPlan = providerPlan
        self.market = market
        self.channel = channel
    }
}
