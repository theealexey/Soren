import Foundation

enum BundledRegionalPricingLoaderError: Error, Equatable, Sendable {
    case resourceNotFound(String)
    case resourceUnreadable(String)
    case jsonDecodingFailed(String)
    case unsupportedSchemaVersion(Int)
    case blankRevision
    case inconsistentRevisions(expected: String, actual: String)
    case emptyManifestCollection
    case invalidMarket(String)
    case invalidProviderID(String)
    case invalidTierID(String)
    case invalidChannel(String)
    case invalidAmount(String)
    case invalidCurrency(String)
    case invalidBillingCycle(String)
    case invalidVerificationDate(String)
    case invalidReviewDate(String)
    case invalidDateRange
    case invalidSourceURL(String)
    case duplicateExactPriceKey(RegionalPriceKey)
    case snapshotConstructionFailed(RegionalPricingSnapshotValidationError)
}

/// Synchronously loads versioned, bundled regional-price manifests into Domain values.
/// DTOs and JSON decoding are intentionally private to this Data-layer boundary.
struct BundledRegionalPricingLoader: Sendable {
    private static let supportedSchemaVersion = 1

    func load(
        resourceNames: [String],
        in bundle: Foundation.Bundle = .main
    ) throws -> RegionalPricingSnapshot {
        guard !resourceNames.isEmpty else {
            throw BundledRegionalPricingLoaderError.emptyManifestCollection
        }

        let manifests = try resourceNames.map { name in
            guard let resourceURL = bundle.url(forResource: name, withExtension: "json") else {
                throw BundledRegionalPricingLoaderError.resourceNotFound(name)
            }

            do {
                return try Data(contentsOf: resourceURL)
            } catch {
                throw BundledRegionalPricingLoaderError.resourceUnreadable(name)
            }
        }

        return try load(manifests: manifests)
    }

    func load(manifests: [Data]) throws -> RegionalPricingSnapshot {
        guard !manifests.isEmpty else {
            throw BundledRegionalPricingLoaderError.emptyManifestCollection
        }

        let decodedManifests = try manifests.map(decodeManifest)
        let revision = try sharedRevision(in: decodedManifests)
        let prices = try decodedManifests.flatMap(mapManifest)

        do {
            return try RegionalPricingSnapshot(
                schemaVersion: Self.supportedSchemaVersion,
                revision: revision,
                prices: prices
            )
        } catch let error as RegionalPricingSnapshotValidationError {
            switch error {
            case .duplicatePriceKey(let key):
                throw BundledRegionalPricingLoaderError.duplicateExactPriceKey(key)
            default:
                throw BundledRegionalPricingLoaderError.snapshotConstructionFailed(error)
            }
        }
    }

    private func decodeManifest(_ data: Data) throws -> ManifestDTO {
        do {
            return try JSONDecoder().decode(ManifestDTO.self, from: data)
        } catch {
            throw BundledRegionalPricingLoaderError.jsonDecodingFailed(String(describing: error))
        }
    }

    private func sharedRevision(in manifests: [ManifestDTO]) throws -> String {
        guard let firstManifest = manifests.first else {
            throw BundledRegionalPricingLoaderError.emptyManifestCollection
        }

        let firstRevision = try validatedRevision(firstManifest.revision)

        for manifest in manifests.dropFirst() {
            let revision = try validatedRevision(manifest.revision)
            guard revision == firstRevision else {
                throw BundledRegionalPricingLoaderError.inconsistentRevisions(
                    expected: firstRevision,
                    actual: revision
                )
            }
        }

        return firstRevision
    }

    private func mapManifest(_ manifest: ManifestDTO) throws -> [RegionalPlanPrice] {
        guard manifest.schemaVersion == Self.supportedSchemaVersion else {
            throw BundledRegionalPricingLoaderError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        let market: PricingMarket
        do {
            market = try PricingMarket(countryCode: manifest.market)
        } catch {
            throw BundledRegionalPricingLoaderError.invalidMarket(manifest.market)
        }

        return try manifest.prices.map { record in
            try map(record: record, market: market)
        }
    }

    private func map(
        record: PriceDTO,
        market: PricingMarket
    ) throws -> RegionalPlanPrice {
        let providerPlan = try providerPlanKey(
            providerID: record.providerID,
            tierID: record.tierID
        )
        let channel = try pricingChannel(from: record.channel)
        let amount = try decimalAmount(from: record.amount)
        let money = try nativeMoney(amount: amount, currency: record.currency)
        let billingCycle = try billingCycle(from: record.billingCycle)
        let verifiedAt = try date(from: record.verifiedAt, error: .invalidVerificationDate(record.verifiedAt))
        let reviewAfter = try date(from: record.reviewAfter, error: .invalidReviewDate(record.reviewAfter))

        guard let sourceURL = URL(string: record.sourceURL) else {
            throw BundledRegionalPricingLoaderError.invalidSourceURL(record.sourceURL)
        }

        let key = RegionalPriceKey(
            providerPlan: providerPlan,
            market: market,
            channel: channel
        )

        do {
            return try RegionalPlanPrice(
                key: key,
                money: money,
                billingCycle: billingCycle,
                verifiedAt: verifiedAt,
                reviewAfter: reviewAfter,
                sourceURL: sourceURL
            )
        } catch let error as RegionalPlanPriceValidationError {
            switch error {
            case .negativeAmount:
                throw BundledRegionalPricingLoaderError.invalidAmount(record.amount)
            case .invalidSourceURL:
                throw BundledRegionalPricingLoaderError.invalidSourceURL(record.sourceURL)
            case .reviewDateMustNotPrecedeVerificationDate:
                throw BundledRegionalPricingLoaderError.invalidDateRange
            }
        }
    }

    private func validatedRevision(_ rawRevision: String) throws -> String {
        let revision = rawRevision.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !revision.isEmpty else {
            throw BundledRegionalPricingLoaderError.blankRevision
        }
        return revision
    }

    private func providerPlanKey(
        providerID: String,
        tierID: String
    ) throws -> ProviderPlanKey {
        do {
            return try ProviderPlanKey(providerID: providerID, tierID: tierID)
        } catch let error as ProviderPlanKeyValidationError {
            switch error {
            case .emptyProviderID:
                throw BundledRegionalPricingLoaderError.invalidProviderID(providerID)
            case .emptyTierID:
                throw BundledRegionalPricingLoaderError.invalidTierID(tierID)
            }
        }
    }

    private func pricingChannel(from rawValue: String) throws -> PricingChannel {
        guard let channel = PricingChannel(rawValue: rawValue) else {
            throw BundledRegionalPricingLoaderError.invalidChannel(rawValue)
        }
        return channel
    }

    private func decimalAmount(from rawValue: String) throws -> Decimal {
        let decimalPattern = "^-?[0-9]+(?:\\.[0-9]+)?$"
        guard rawValue.range(of: decimalPattern, options: .regularExpression) != nil,
              let amount = Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX")) else {
            throw BundledRegionalPricingLoaderError.invalidAmount(rawValue)
        }
        return amount
    }

    private func nativeMoney(
        amount: Decimal,
        currency: String
    ) throws -> Money {
        do {
            return try Money(amount: amount, currencyCode: currency)
        } catch {
            throw BundledRegionalPricingLoaderError.invalidCurrency(currency)
        }
    }

    private func billingCycle(from rawValue: String) throws -> BillingCycle {
        switch rawValue {
        case "weekly": .weekly
        case "monthly": .monthly
        case "quarterly": .quarterly
        case "semiannual": .semiannual
        case "annual": .annual
        default: throw BundledRegionalPricingLoaderError.invalidBillingCycle(rawValue)
        }
    }

    private func date(
        from rawValue: String,
        error: BundledRegionalPricingLoaderError
    ) throws -> Date {
        guard rawValue.hasSuffix("Z") else {
            throw error
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: rawValue) else {
            throw error
        }
        return date
    }
}

private struct ManifestDTO: Decodable {
    let schemaVersion: Int
    let revision: String
    let market: String
    let prices: [PriceDTO]
}

private struct PriceDTO: Decodable {
    let providerID: String
    let tierID: String
    let channel: String
    let amount: String
    let currency: String
    let billingCycle: String
    let verifiedAt: String
    let reviewAfter: String
    let sourceURL: String
}
