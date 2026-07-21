import Foundation
import Testing
@testable import Soren

@Suite("Bundled Regional Pricing Loader")
struct BundledRegionalPricingLoaderTests {
    private let loader = BundledRegionalPricingLoader()
    private let verifiedAt = "2026-07-01T00:00:00Z"
    private let reviewAfter = "2026-08-01T00:00:00Z"

    private func data(_ json: String) throws -> Data {
        try #require(json.data(using: .utf8))
    }

    private func priceJSON(
        providerID: String = "fixture-provider",
        tierID: String = "fixture-plan",
        channel: String = "providerDirect",
        amount: String = "12.99",
        currency: String = "USD",
        billingCycle: String = "monthly",
        verifiedAt: String? = nil,
        reviewAfter: String? = nil,
        sourceURL: String = "https://example.com/pricing"
    ) -> String {
        """
        {
          "providerID": "\(providerID)",
          "tierID": "\(tierID)",
          "channel": "\(channel)",
          "amount": "\(amount)",
          "currency": "\(currency)",
          "billingCycle": "\(billingCycle)",
          "verifiedAt": "\(verifiedAt ?? self.verifiedAt)",
          "reviewAfter": "\(reviewAfter ?? self.reviewAfter)",
          "sourceURL": "\(sourceURL)"
        }
        """
    }

    private func manifestJSON(
        schemaVersion: Int = 1,
        revision: String = "fixture-2026-07-21",
        market: String = "US",
        prices: [String]? = nil
    ) -> String {
        let records = prices ?? [priceJSON()]
        return """
        {
          "schemaVersion": \(schemaVersion),
          "revision": "\(revision)",
          "market": "\(market)",
          "prices": [\(records.joined(separator: ","))]
        }
        """
    }

    @Test("A valid manifest maps every native Domain field and resolves exactly")
    func validManifestMapsAndResolvesExactly() throws {
        let snapshot = try loader.load(manifests: [data(manifestJSON())])
        let key = RegionalPriceKey(
            providerPlan: try ProviderPlanKey(providerID: "fixture-provider", tierID: "fixture-plan"),
            market: try PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let expectedAmount = try #require(Decimal(string: "12.99"))
        let expectedVerifiedAt = try #require(ISO8601DateFormatter().date(from: verifiedAt))
        let expectedReviewAfter = try #require(ISO8601DateFormatter().date(from: reviewAfter))
        let expectedSourceURL = try #require(URL(string: "https://example.com/pricing"))

        let price = try #require(snapshot.price(for: key))

        #expect(price.money.amount == expectedAmount)
        #expect(price.money.currencyCode == "USD")
        #expect(price.billingCycle == .monthly)
        #expect(price.verifiedAt == expectedVerifiedAt)
        #expect(price.reviewAfter == expectedReviewAfter)
        #expect(price.sourceURL == expectedSourceURL)
        #expect(
            ResolveRegionalPlanPriceUseCase().execute(
                key: key,
                snapshot: snapshot,
                asOf: expectedVerifiedAt
            ) == .available(price)
        )
    }

    @Test("Manifests with one revision combine different markets without dropping records")
    func manifestsCombineDifferentMarkets() throws {
        let us = try data(manifestJSON(market: "US"))
        let ru = try data(manifestJSON(
            market: "RU",
            prices: [priceJSON(providerID: "fixture-ru", currency: "RUB")]
        ))

        let snapshot = try loader.load(manifests: [us, ru])
        let usKey = RegionalPriceKey(
            providerPlan: try ProviderPlanKey(providerID: "fixture-provider", tierID: "fixture-plan"),
            market: try PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let ruKey = RegionalPriceKey(
            providerPlan: try ProviderPlanKey(providerID: "fixture-ru", tierID: "fixture-plan"),
            market: try PricingMarket(countryCode: "RU"),
            channel: .providerDirect
        )

        #expect(snapshot.price(for: usKey) != nil)
        #expect(snapshot.price(for: ruKey) != nil)
    }

    @Test("Amounts preserve exact Decimal precision and numeric zero")
    func decimalPrecisionAndZeroArePreserved() throws {
        let precise = priceJSON(providerID: "fixture-precise", amount: "1234567890.123456789")
        let zero = priceJSON(providerID: "fixture-zero", amount: "0")
        let snapshot = try loader.load(manifests: [data(manifestJSON(prices: [precise, zero]))])
        let preciseKey = RegionalPriceKey(
            providerPlan: try ProviderPlanKey(providerID: "fixture-precise", tierID: "fixture-plan"),
            market: try PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )
        let zeroKey = RegionalPriceKey(
            providerPlan: try ProviderPlanKey(providerID: "fixture-zero", tierID: "fixture-plan"),
            market: try PricingMarket(countryCode: "US"),
            channel: .providerDirect
        )

        #expect(snapshot.price(for: preciseKey)?.money.amount == Decimal(string: "1234567890.123456789"))
        #expect(snapshot.price(for: zeroKey)?.money.amount == .zero)
    }

    @Test("Lowercase manifest markets use accepted Domain normalization")
    func lowercaseMarketNormalizes() throws {
        let snapshot = try loader.load(manifests: [data(manifestJSON(market: "us"))])
        let market = try PricingMarket(countryCode: "US")

        #expect(snapshot.containsPrices(in: market))
    }

    @Test("Missing resources and empty manifest collections use typed errors")
    func missingResourceAndEmptyCollectionFail() throws {
        #expect(throws: BundledRegionalPricingLoaderError.emptyManifestCollection) {
            try loader.load(manifests: [])
        }
        #expect(throws: BundledRegionalPricingLoaderError.resourceNotFound("NoSuchRegionalPricingFixture")) {
            try loader.load(resourceNames: ["NoSuchRegionalPricingFixture"], in: .main)
        }
    }

    @Test("Manifest metadata failures are typed")
    func manifestMetadataFailures() throws {
        #expect(throws: BundledRegionalPricingLoaderError.unsupportedSchemaVersion(2)) {
            try loader.load(manifests: [data(manifestJSON(schemaVersion: 2))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.blankRevision) {
            try loader.load(manifests: [data(manifestJSON(revision: "  "))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.inconsistentRevisions(
            expected: "fixture-2026-07-21",
            actual: "fixture-2026-07-22"
        )) {
            try loader.load(manifests: [
                data(manifestJSON()),
                data(manifestJSON(revision: "fixture-2026-07-22", market: "RU"))
            ])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidMarket("USA")) {
            try loader.load(manifests: [data(manifestJSON(market: "USA"))])
        }
    }

    @Test("Malformed JSON is a typed decoding failure")
    func malformedJSONFails() throws {
        do {
            _ = try loader.load(manifests: [data("{not-json}")])
            Issue.record("Expected malformed JSON to fail")
        } catch let error as BundledRegionalPricingLoaderError {
            guard case .jsonDecodingFailed = error else {
                Issue.record("Expected JSON decoding failure, got \(error)")
                return
            }
        }
    }

    @Test("Provider, tier and channel mapping failures are typed")
    func identityAndChannelFailures() throws {
        #expect(throws: BundledRegionalPricingLoaderError.invalidProviderID("")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(providerID: "")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidTierID("")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(tierID: "")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidChannel("unknown")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(channel: "unknown")]))])
        }
    }

    @Test("Invalid amount strings never decode through Double")
    func invalidAmountStringsFail() throws {
        for amount in ["", "abc", "12,99", "12.99USD"] {
            #expect(throws: BundledRegionalPricingLoaderError.invalidAmount(amount)) {
                try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(amount: amount)]))])
            }
        }
    }

    @Test("Currency and billing cycle mapping failures are typed")
    func currencyAndBillingCycleFailures() throws {
        #expect(throws: BundledRegionalPricingLoaderError.invalidCurrency("US")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(currency: "US")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidBillingCycle("daily")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(billingCycle: "daily")]))])
        }
    }

    @Test("Malformed and timezone-free dates are typed failures")
    func dateParsingFailures() throws {
        #expect(throws: BundledRegionalPricingLoaderError.invalidVerificationDate("not-a-date")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(verifiedAt: "not-a-date")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidReviewDate("2026-08-01T00:00:00")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(reviewAfter: "2026-08-01T00:00:00")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidDateRange) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(
                verifiedAt: "2026-08-01T00:00:00Z",
                reviewAfter: "2026-07-01T00:00:00Z"
            )]))])
        }
    }

    @Test("Source URL validation remains owned by the accepted Domain model")
    func sourceURLFailures() throws {
        #expect(throws: BundledRegionalPricingLoaderError.invalidSourceURL("http://example.com/pricing")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(sourceURL: "http://example.com/pricing")]))])
        }
        #expect(throws: BundledRegionalPricingLoaderError.invalidSourceURL("/pricing")) {
            try loader.load(manifests: [data(manifestJSON(prices: [priceJSON(sourceURL: "/pricing")]))])
        }
    }

    @Test("Duplicate exact keys inside and across manifests fail without overwrite")
    func duplicateKeysFail() throws {
        let record = priceJSON()

        #expect(throws: BundledRegionalPricingLoaderError.duplicateExactPriceKey(
            try RegionalPriceKey(
                providerPlan: ProviderPlanKey(providerID: "fixture-provider", tierID: "fixture-plan"),
                market: PricingMarket(countryCode: "US"),
                channel: .providerDirect
            )
        )) {
            try loader.load(manifests: [data(manifestJSON(prices: [record, record]))])
        }

        #expect(throws: BundledRegionalPricingLoaderError.duplicateExactPriceKey(
            try RegionalPriceKey(
                providerPlan: ProviderPlanKey(providerID: "fixture-provider", tierID: "fixture-plan"),
                market: PricingMarket(countryCode: "US"),
                channel: .providerDirect
            )
        )) {
            try loader.load(manifests: [data(manifestJSON()), data(manifestJSON())])
        }
    }

    @Test("The same provider plan may use different market and channel exact keys")
    func differentMarketAndChannelKeysSucceed() throws {
        let usDirect = try data(manifestJSON())
        let usAppStore = try data(manifestJSON(
            market: "US",
            prices: [priceJSON(channel: "appleAppStore")]
        ))
        let ruDirect = try data(manifestJSON(market: "RU"))

        let snapshot = try loader.load(manifests: [usDirect, usAppStore, ruDirect])

        #expect(snapshot.containsPrices(in: try PricingMarket(countryCode: "US")))
        #expect(snapshot.containsPrices(in: try PricingMarket(countryCode: "RU")))
    }
}
