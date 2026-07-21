import Foundation
import Testing
@testable import Soren

@Suite("Production Regional Pricing Manifests")
struct ProductionRegionalPricingManifestTests {
    private static let revision = "2026-07-21.1"
    private static let verifiedAt = "2026-07-21T21:18:03Z"
    private static let reviewAfter = "2026-08-20T21:18:03Z"
    private static let usResourceName = "regional-pricing-us-v1"
    private static let ruResourceName = "regional-pricing-ru-v1"

    private let loader = BundledRegionalPricingLoader()

    @Test("Production manifests are bundled, validated, and resolve the accepted dataset")
    func productionManifestsLoadAndResolveExactly() throws {
        let bundle = try applicationBundle()
        let usData = try manifestData(named: Self.usResourceName, in: bundle)
        let ruData = try manifestData(named: Self.ruResourceName, in: bundle)
        let usManifest = try JSONDecoder().decode(ManifestShape.self, from: usData)
        let ruManifest = try JSONDecoder().decode(ManifestShape.self, from: ruData)

        try validate(manifest: usManifest, expectedMarket: "US", expectedRecords: usRecords)
        try validate(manifest: ruManifest, expectedMarket: "RU", expectedRecords: ruRecords)

        let snapshot = try loader.load(
            resourceNames: [Self.usResourceName, Self.ruResourceName],
            in: bundle
        )
        let expected = usRecords + ruRecords
        let keys = try Set(expected.map { record in
            try regionalPriceKey(for: record)
        })

        #expect(usManifest.prices.count == 26)
        #expect(ruManifest.prices.count == 1)
        #expect(expected.count == 27)
        #expect(keys.count == 27)
        #expect(snapshot.revision == Self.revision)

        let reviewDate = try iso8601Date(Self.reviewAfter)
        let afterReviewDate = reviewDate.addingTimeInterval(1)
        for record in expected {
            let key = try regionalPriceKey(for: record)
            let price = try #require(snapshot.price(for: key))
            let amount = try #require(Decimal(string: record.amount, locale: Locale(identifier: "en_US_POSIX")))

            #expect(price.money.amount == amount)
            #expect(price.money.currencyCode == record.currency)
            #expect(price.billingCycle == record.billingCycle)
            #expect(price.key.channel == .providerDirect)
            #expect(
                ResolveRegionalPlanPriceUseCase().execute(
                    key: key,
                    snapshot: snapshot,
                    asOf: reviewDate
                ) == .available(price)
            )
            #expect(
                ResolveRegionalPlanPriceUseCase().execute(
                    key: key,
                    snapshot: snapshot,
                    asOf: afterReviewDate
                ) == .requiresReview(price)
            )
        }

        let missingUSKey = try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: "missing-provider", tierID: "missing-tier"),
            market: PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let missingRUKey = try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: "missing-provider", tierID: "missing-tier"),
            market: PricingMarket(countryCode: "RU"),
            channel: .providerDirect
        )
        let unsupportedMarketKey = try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: "missing-provider", tierID: "missing-tier"),
            market: PricingMarket(countryCode: "GB"),
            channel: .providerDirect
        )

        #expect(
            ResolveRegionalPlanPriceUseCase().execute(
                key: missingUSKey,
                snapshot: snapshot,
                asOf: reviewDate
            ) == .unavailable(.priceNotFound)
        )
        #expect(
            ResolveRegionalPlanPriceUseCase().execute(
                key: missingRUKey,
                snapshot: snapshot,
                asOf: reviewDate
            ) == .unavailable(.priceNotFound)
        )
        #expect(
            ResolveRegionalPlanPriceUseCase().execute(
                key: unsupportedMarketKey,
                snapshot: snapshot,
                asOf: reviewDate
            ) == .unavailable(.marketNotSupported)
        )
    }

    private func applicationBundle() throws -> Bundle {
        if Bundle.main.bundleIdentifier == "com.alexey.soren" {
            return Bundle.main
        }

        return try #require(
            Bundle.allBundles.first { bundle in
                bundle.bundleIdentifier == "com.alexey.soren"
            }
        )
    }

    private func manifestData(
        named resourceName: String,
        in bundle: Bundle
    ) throws -> Data {
        let resourceURL = try #require(
            bundle.url(forResource: resourceName, withExtension: "json")
        )
        return try Data(contentsOf: resourceURL)
    }

    private func validate(
        manifest: ManifestShape,
        expectedMarket: String,
        expectedRecords: [ExpectedRecord]
    ) throws {
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.revision == Self.revision)
        #expect(manifest.market == expectedMarket)
        #expect(manifest.prices.count == expectedRecords.count)

        let expectedByID = Dictionary(
            uniqueKeysWithValues: expectedRecords.map { record in
                ("\(record.providerID)/\(record.tierID)", record)
            }
        )
        let market = try PricingMarket(countryCode: expectedMarket)
        let verificationDate = try iso8601Date(Self.verifiedAt)
        let reviewDate = try iso8601Date(Self.reviewAfter)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        #expect(calendar.date(byAdding: .day, value: 30, to: verificationDate) == reviewDate)

        for price in manifest.prices {
            let identifier = "\(price.providerID)/\(price.tierID)"
            let expected = try #require(expectedByID[identifier])
            let amount = try #require(Decimal(string: price.amount, locale: Locale(identifier: "en_US_POSIX")))
            let sourceURL = try #require(URL(string: price.sourceURL))
            let provider = try #require(ProviderCatalog.template(forProviderID: price.providerID))

            #expect(price.channel == PricingChannel.providerDirect.rawValue)
            #expect(price.amount == expected.amount)
            #expect(price.currency == expected.currency)
            #expect(price.billingCycle == billingCycleValue(for: expected.billingCycle))
            #expect(price.verifiedAt == Self.verifiedAt)
            #expect(price.reviewAfter == Self.reviewAfter)
            #expect(amount >= .zero)
            #expect(amount != .zero)
            #expect(sourceURL.scheme?.lowercased() == "https")
            #expect(sourceURL.host != nil)
            #expect(provider.plans.contains { plan in plan.id == price.tierID })
            let manifestKey = try RegionalPriceKey(
                providerPlan: ProviderPlanKey(providerID: price.providerID, tierID: price.tierID),
                market: market,
                channel: .providerDirect
            )
            let expectedKey = try regionalPriceKey(for: expected)

            #expect(manifestKey == expectedKey)
        }
    }

    private func regionalPriceKey(for record: ExpectedRecord) throws -> RegionalPriceKey {
        try RegionalPriceKey(
            providerPlan: ProviderPlanKey(providerID: record.providerID, tierID: record.tierID),
            market: PricingMarket(countryCode: record.market),
            channel: .providerDirect
        )
    }

    private func iso8601Date(_ value: String) throws -> Date {
        try #require(ISO8601DateFormatter().date(from: value))
    }

    private func billingCycleValue(for billingCycle: BillingCycle) -> String {
        switch billingCycle {
        case .weekly: "weekly"
        case .monthly: "monthly"
        case .quarterly: "quarterly"
        case .semiannual: "semiannual"
        case .annual: "annual"
        case .custom(let days): "custom-\(days)"
        }
    }

    private var usRecords: [ExpectedRecord] {
        [
            .init("netflix", "standard_ads", "US", "8.99", "USD", .monthly),
            .init("disney_plus", "with_ads", "US", "11.99", "USD", .monthly),
            .init("disney_plus", "standard", "US", "18.99", "USD", .monthly),
            .init("disney_plus", "standard_annual", "US", "189.99", "USD", .annual),
            .init("apple_tv_plus", "monthly", "US", "12.99", "USD", .monthly),
            .init("spotify", "individual", "US", "12.99", "USD", .monthly),
            .init("spotify", "duo", "US", "18.99", "USD", .monthly),
            .init("spotify", "family", "US", "21.99", "USD", .monthly),
            .init("spotify", "student", "US", "6.99", "USD", .monthly),
            .init("apple_music", "individual", "US", "11.99", "USD", .monthly),
            .init("apple_music", "family", "US", "19.99", "USD", .monthly),
            .init("apple_music", "student", "US", "6.99", "USD", .monthly),
            .init("icloud", "50gb", "US", "0.99", "USD", .monthly),
            .init("icloud", "200gb", "US", "2.99", "USD", .monthly),
            .init("icloud", "2tb", "US", "9.99", "USD", .monthly),
            .init("icloud", "6tb", "US", "29.99", "USD", .monthly),
            .init("icloud", "12tb", "US", "59.99", "USD", .monthly),
            .init("microsoft_365", "personal", "US", "9.99", "USD", .monthly),
            .init("microsoft_365", "personal_annual", "US", "99.99", "USD", .annual),
            .init("microsoft_365", "family", "US", "12.99", "USD", .monthly),
            .init("microsoft_365", "family_annual", "US", "129.99", "USD", .annual),
            .init("apple_arcade", "monthly", "US", "6.99", "USD", .monthly),
            .init("apple_arcade", "annual", "US", "49.99", "USD", .annual),
            .init("apple_one", "individual", "US", "19.95", "USD", .monthly),
            .init("apple_one", "family", "US", "27.95", "USD", .monthly),
            .init("apple_one", "premier", "US", "39.95", "USD", .monthly)
        ]
    }

    private var ruRecords: [ExpectedRecord] {
        [
            .init("tbank_pro", "pro", "RU", "299", "RUB", .monthly)
        ]
    }
}

private struct ManifestShape: Decodable {
    let schemaVersion: Int
    let revision: String
    let market: String
    let prices: [ManifestPriceShape]
}

private struct ManifestPriceShape: Decodable {
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

private struct ExpectedRecord: Hashable {
    let providerID: String
    let tierID: String
    let market: String
    let amount: String
    let currency: String
    let billingCycle: BillingCycle

    init(
        _ providerID: String,
        _ tierID: String,
        _ market: String,
        _ amount: String,
        _ currency: String,
        _ billingCycle: BillingCycle
    ) {
        self.providerID = providerID
        self.tierID = tierID
        self.market = market
        self.amount = amount
        self.currency = currency
        self.billingCycle = billingCycle
    }
}
