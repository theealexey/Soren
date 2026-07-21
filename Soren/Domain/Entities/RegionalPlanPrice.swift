import Foundation

// MARK: - Regional Plan Price

enum RegionalPlanPriceValidationError: Error, Equatable, Sendable {
    case negativeAmount
    case invalidSourceURL
    case reviewDateMustNotPrecedeVerificationDate
}

/// A verified native recurring-price suggestion for one exact provider plan,
/// billing market and purchase channel. It never represents a converted value.
struct RegionalPlanPrice: Equatable, Sendable {
    let key: RegionalPriceKey
    let money: Money
    let billingCycle: BillingCycle
    let verifiedAt: Date
    let reviewAfter: Date
    let sourceURL: URL

    init(
        key: RegionalPriceKey,
        money: Money,
        billingCycle: BillingCycle,
        verifiedAt: Date,
        reviewAfter: Date,
        sourceURL: URL
    ) throws {
        guard money.amount >= .zero else {
            throw RegionalPlanPriceValidationError.negativeAmount
        }
        guard sourceURL.scheme?.lowercased() == "https", sourceURL.host != nil else {
            throw RegionalPlanPriceValidationError.invalidSourceURL
        }
        guard reviewAfter >= verifiedAt else {
            throw RegionalPlanPriceValidationError.reviewDateMustNotPrecedeVerificationDate
        }

        self.key = key
        self.money = money
        self.billingCycle = billingCycle
        self.verifiedAt = verifiedAt
        self.reviewAfter = reviewAfter
        self.sourceURL = sourceURL
    }
}

// MARK: - Regional Pricing Snapshot

enum RegionalPricingSnapshotValidationError: Error, Equatable, Sendable {
    case invalidSchemaVersion(Int)
    case emptyRevision
    case duplicatePriceKey(RegionalPriceKey)
}

/// Immutable, validated index of bundled regional pricing data.
/// Data loading and manifest decoding belong to a later Data-layer phase.
struct RegionalPricingSnapshot: Equatable, Sendable {
    let schemaVersion: Int
    let revision: String

    private let pricesByKey: [RegionalPriceKey: RegionalPlanPrice]

    init(
        schemaVersion: Int,
        revision: String,
        prices: [RegionalPlanPrice]
    ) throws {
        guard schemaVersion > 0 else {
            throw RegionalPricingSnapshotValidationError.invalidSchemaVersion(schemaVersion)
        }

        let normalizedRevision = revision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRevision.isEmpty else {
            throw RegionalPricingSnapshotValidationError.emptyRevision
        }

        var index: [RegionalPriceKey: RegionalPlanPrice] = [:]
        for price in prices {
            guard index[price.key] == nil else {
                throw RegionalPricingSnapshotValidationError.duplicatePriceKey(price.key)
            }
            index[price.key] = price
        }

        self.schemaVersion = schemaVersion
        self.revision = normalizedRevision
        self.pricesByKey = index
    }

    func price(for key: RegionalPriceKey) -> RegionalPlanPrice? {
        pricesByKey[key]
    }

    func containsPrices(in market: PricingMarket) -> Bool {
        pricesByKey.values.contains { $0.key.market == market }
    }
}

// MARK: - Resolution State

enum RegionalPriceUnavailableReason: Equatable, Sendable {
    case marketNotSupported
    case priceNotFound
}

/// Typed resolution result for a price suggestion.
/// `requiresReview` deliberately does not become an auto-fillable price.
enum RegionalPriceResolution: Equatable, Sendable {
    case available(RegionalPlanPrice)
    case unavailable(RegionalPriceUnavailableReason)
    case requiresReview(RegionalPlanPrice)
}
