import Foundation
import Testing
@testable import Soren

@Suite("Regional Pricing Domain")
struct RegionalPricingDomainTests {
    private let verifiedAt = Date(timeIntervalSince1970: 1_700_000_000)
    private let reviewAfter = Date(timeIntervalSince1970: 1_800_000_000)

    private func makePrice(
        providerID: String = "spotify",
        tierID: String = "individual",
        marketCode: String = "US",
        channel: PricingChannel = .providerDirect,
        amount: String = "12.99",
        billingCycle: BillingCycle = .monthly,
        verifiedAt: Date? = nil,
        reviewAfter: Date? = nil,
        sourceURL: URL? = nil
    ) throws -> RegionalPlanPrice {
        let providerPlan = try ProviderPlanKey(providerID: providerID, tierID: tierID)
        let market = try PricingMarket(countryCode: marketCode)
        let key = RegionalPriceKey(
            providerPlan: providerPlan,
            market: market,
            channel: channel
        )
        let decimal = try #require(Decimal(string: amount))
        let money = try Money(amount: decimal, currencyCode: "USD")
        let resolvedSourceURL = try #require(
            sourceURL ?? URL(string: "https://pricing.example.com/plan")
        )

        return try RegionalPlanPrice(
            key: key,
            money: money,
            billingCycle: billingCycle,
            verifiedAt: verifiedAt ?? self.verifiedAt,
            reviewAfter: reviewAfter ?? self.reviewAfter,
            sourceURL: resolvedSourceURL
        )
    }

    private func makeSnapshot(_ prices: [RegionalPlanPrice]) throws -> RegionalPricingSnapshot {
        try RegionalPricingSnapshot(
            schemaVersion: 1,
            revision: "2026-07-21",
            prices: prices
        )
    }

    @Test("Pricing market strictly normalizes ISO alpha-2 ASCII country codes")
    func pricingMarketValidation() throws {
        let uppercase = try PricingMarket(countryCode: "US")
        let lowercase = try PricingMarket(countryCode: "us")
        let padded = try PricingMarket(countryCode: " US ")

        #expect(uppercase.countryCode == "US")
        #expect(lowercase.countryCode == "US")
        #expect(padded.countryCode == "US")

        for input in ["", "U", "USA", "U1", "U!", "ЖС"] {
            #expect(throws: PricingMarketValidationError.invalidCountryCode(input)) {
                try PricingMarket(countryCode: input)
            }
        }
    }

    @Test("Provider plan identity keeps provider and tier IDs distinct")
    func providerPlanIdentityIsComposite() throws {
        let spotify = try ProviderPlanKey(providerID: "spotify", tierID: "individual")
        let appleMusic = try ProviderPlanKey(providerID: "apple_music", tierID: "individual")
        let differentlyCased = try ProviderPlanKey(providerID: "Spotify", tierID: "individual")

        #expect(spotify != appleMusic)
        #expect(spotify != differentlyCased)
        #expect(throws: ProviderPlanKeyValidationError.emptyTierID) {
            try ProviderPlanKey(providerID: "spotify", tierID: "   ")
        }
    }

    @Test("Regional price keys require all provider, tier, market and channel dimensions")
    func regionalPriceKeyUsesEveryIdentityDimension() throws {
        let providerPlan = try ProviderPlanKey(providerID: "spotify", tierID: "individual")
        let differentTier = try ProviderPlanKey(providerID: "spotify", tierID: "duo")
        let usMarket = try PricingMarket(countryCode: "US")
        let ruMarket = try PricingMarket(countryCode: "RU")

        let direct = RegionalPriceKey(
            providerPlan: providerPlan,
            market: usMarket,
            channel: .providerDirect
        )

        #expect(direct != RegionalPriceKey(
            providerPlan: differentTier,
            market: usMarket,
            channel: .providerDirect
        ))
        #expect(direct != RegionalPriceKey(
            providerPlan: providerPlan,
            market: ruMarket,
            channel: .providerDirect
        ))
        #expect(direct != RegionalPriceKey(
            providerPlan: providerPlan,
            market: usMarket,
            channel: .appleAppStore
        ))
    }

    @Test("Exact provider, tier, market and channel resolve a native price")
    func exactResolution() throws {
        let price = try makePrice()
        let snapshot = try makeSnapshot([price])
        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: price.key,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        let expectedAmount = try #require(Decimal(string: "12.99"))

        #expect(result == .available(price))
        #expect(price.money.amount == expectedAmount)
        #expect(price.money.currencyCode == "USD")
        #expect(price.billingCycle == .monthly)
    }

    @Test("Same tier IDs from different providers never collide")
    func sameTierIDsDoNotCollide() throws {
        let spotify = try makePrice(providerID: "spotify", amount: "12.99")
        let appleMusic = try makePrice(providerID: "apple_music", amount: "10.99")
        let snapshot = try makeSnapshot([spotify, appleMusic])

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: appleMusic.key,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .available(appleMusic))
    }

    @Test("A market absent from the whole snapshot is not supported")
    func globallyUnsupportedMarketIsUnavailable() throws {
        let ruPrice = try makePrice(marketCode: "RU")
        let snapshot = try makeSnapshot([ruPrice])
        let usMarket = try PricingMarket(countryCode: "US")
        let usKey = RegionalPriceKey(
            providerPlan: ruPrice.key.providerPlan,
            market: usMarket,
            channel: .providerDirect
        )

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: usKey,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .unavailable(.marketNotSupported))
    }

    @Test("A price from another purchase channel never becomes an implicit fallback")
    func missingChannelHasNoFallback() throws {
        let directPrice = try makePrice()
        let snapshot = try makeSnapshot([directPrice])
        let appStoreKey = RegionalPriceKey(
            providerPlan: directPrice.key.providerPlan,
            market: directPrice.key.market,
            channel: .appleAppStore
        )

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: appStoreKey,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .unavailable(.priceNotFound))
    }

    @Test("Unknown provider plan resolves to a typed unavailable state")
    func unknownProviderPlanIsUnavailable() throws {
        let snapshot = try makeSnapshot([try makePrice()])
        let unknownPlan = try ProviderPlanKey(providerID: "netflix", tierID: "standard")
        let market = try PricingMarket(countryCode: "US")
        let key = RegionalPriceKey(
            providerPlan: unknownPlan,
            market: market,
            channel: .providerDirect
        )

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: key,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .unavailable(.priceNotFound))
    }

    @Test("Missing tier and localized names cannot resolve a configured provider plan")
    func missingTierAndLocalizedNameAreUnavailable() throws {
        let configured = try makePrice()
        let snapshot = try makeSnapshot([configured])
        let usMarket = try PricingMarket(countryCode: "US")
        let missingTier = try ProviderPlanKey(providerID: "spotify", tierID: "duo")
        let localizedProvider = try ProviderPlanKey(providerID: "Спотифай", tierID: "individual")

        let missingTierResult = ResolveRegionalPlanPriceUseCase().execute(
            key: RegionalPriceKey(
                providerPlan: missingTier,
                market: usMarket,
                channel: .providerDirect
            ),
            snapshot: snapshot,
            asOf: verifiedAt
        )
        let localizedNameResult = ResolveRegionalPlanPriceUseCase().execute(
            key: RegionalPriceKey(
                providerPlan: localizedProvider,
                market: usMarket,
                channel: .providerDirect
            ),
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(missingTierResult == .unavailable(.priceNotFound))
        #expect(localizedNameResult == .unavailable(.priceNotFound))
    }

    @Test("A quote before its inclusive review boundary remains available")
    func reviewBeforeBoundaryIsAvailable() throws {
        let price = try makePrice()
        let snapshot = try makeSnapshot([price])

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: price.key,
            snapshot: snapshot,
            asOf: reviewAfter.addingTimeInterval(-1)
        )

        #expect(result == .available(price))
    }

    @Test("A quote at its inclusive review boundary remains available")
    func reviewBoundaryIsAvailable() throws {
        let price = try makePrice()
        let snapshot = try makeSnapshot([price])

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: price.key,
            snapshot: snapshot,
            asOf: reviewAfter
        )

        #expect(result == .available(price))
    }

    @Test("An expired quote requires review while preserving native price fields")
    func expiredQuoteRequiresReviewWithOriginalPrice() throws {
        let price = try makePrice(billingCycle: .annual)
        let snapshot = try makeSnapshot([price])
        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: price.key,
            snapshot: snapshot,
            asOf: reviewAfter.addingTimeInterval(1)
        )

        guard case let .requiresReview(resolvedPrice) = result else {
            Issue.record("Expected an expired quote to require review")
            return
        }

        #expect(resolvedPrice.money == price.money)
        #expect(resolvedPrice.billingCycle == .annual)
        #expect(resolvedPrice.verifiedAt == price.verifiedAt)
        #expect(resolvedPrice.reviewAfter == price.reviewAfter)
    }

    @Test("Resolution preserves the verified Decimal amount without conversion or rounding")
    func resolutionPreservesDecimalPrecision() throws {
        let price = try makePrice(amount: "12.990123456789")
        let snapshot = try makeSnapshot([price])
        let expectedAmount = try #require(Decimal(string: "12.990123456789"))

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: price.key,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .available(price))
        #expect(price.money.amount == expectedAmount)
        #expect(price.money.currencyCode == "USD")
    }

    @Test("Unavailable resolution never synthesizes a zero-valued price")
    func unavailableResolutionDoesNotProduceZeroPrice() throws {
        let usPrice = try makePrice(marketCode: "US")
        let snapshot = try makeSnapshot([usPrice])
        let ruMarket = try PricingMarket(countryCode: "RU")
        let ruKey = RegionalPriceKey(
            providerPlan: usPrice.key.providerPlan,
            market: ruMarket,
            channel: .providerDirect
        )

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: ruKey,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        guard case .unavailable = result else {
            Issue.record("Expected an unavailable result instead of a synthesized price")
            return
        }
    }

    @Test("A verified native zero price remains available and is not unavailable")
    func zeroPriceRemainsNumeric() throws {
        let zeroPrice = try makePrice(amount: "0")
        let snapshot = try makeSnapshot([zeroPrice])

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: zeroPrice.key,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(zeroPrice.money.amount == .zero)
        #expect(result == .available(zeroPrice))
        #expect(
            ResolveRegionalPlanPriceUseCase().execute(
                key: zeroPrice.key,
                snapshot: snapshot,
                asOf: reviewAfter.addingTimeInterval(1)
            ) == .requiresReview(zeroPrice)
        )
    }

    @Test("A plan in another market cannot satisfy an exact-key miss in a globally supported market")
    func crossMarketPriceDoesNotFallbackWhenRequestedMarketIsSupported() throws {
        let spotifyUS = try makePrice(providerID: "spotify", marketCode: "US")
        let appleMusicRU = try makePrice(providerID: "apple_music", marketCode: "RU")
        let snapshot = try makeSnapshot([spotifyUS, appleMusicRU])
        let ruMarket = try PricingMarket(countryCode: "RU")
        let spotifyRU = RegionalPriceKey(
            providerPlan: spotifyUS.key.providerPlan,
            market: ruMarket,
            channel: .providerDirect
        )

        let result = ResolveRegionalPlanPriceUseCase().execute(
            key: spotifyRU,
            snapshot: snapshot,
            asOf: verifiedAt
        )

        #expect(result == .unavailable(.priceNotFound))
    }

    @Test("One plan may have exact quotes for multiple markets and channels")
    func snapshotAllowsDistinctMarketAndChannelQuotes() throws {
        let usDirect = try makePrice(marketCode: "US", channel: .providerDirect)
        let ruDirect = try makePrice(marketCode: "RU", channel: .providerDirect)
        let usAppStore = try makePrice(marketCode: "US", channel: .appleAppStore)
        let snapshot = try makeSnapshot([usDirect, ruDirect, usAppStore])
        let resolver = ResolveRegionalPlanPriceUseCase()

        #expect(resolver.execute(key: usDirect.key, snapshot: snapshot, asOf: verifiedAt) == .available(usDirect))
        #expect(resolver.execute(key: ruDirect.key, snapshot: snapshot, asOf: verifiedAt) == .available(ruDirect))
        #expect(resolver.execute(key: usAppStore.key, snapshot: snapshot, asOf: verifiedAt) == .available(usAppStore))
    }

    @Test("Snapshot rejects duplicate exact price keys")
    func snapshotRejectsDuplicateExactKeys() throws {
        let first = try makePrice(amount: "12.99")
        let duplicate = try makePrice(amount: "13.99")

        #expect(throws: RegionalPricingSnapshotValidationError.duplicatePriceKey(first.key)) {
            try makeSnapshot([first, duplicate])
        }
    }

    @Test("Price validation rejects negatives, invalid sources and invalid review windows")
    func priceValidation() throws {
        let providerPlan = try ProviderPlanKey(providerID: "spotify", tierID: "individual")
        let market = try PricingMarket(countryCode: "US")
        let key = RegionalPriceKey(
            providerPlan: providerPlan,
            market: market,
            channel: .providerDirect
        )
        let negativeMoney = try Money(amount: -1, currencyCode: "USD")
        let validMoney = try Money(amount: 12.99, currencyCode: "USD")
        let httpsURL = try #require(URL(string: "https://pricing.example.com/plan"))
        let httpURL = try #require(URL(string: "http://pricing.example.com/plan"))

        let relativeURL = try #require(URL(string: "/pricing"))

        #expect(throws: RegionalPlanPriceValidationError.negativeAmount) {
            try RegionalPlanPrice(
                key: key,
                money: negativeMoney,
                billingCycle: .monthly,
                verifiedAt: verifiedAt,
                reviewAfter: reviewAfter,
                sourceURL: httpsURL
            )
        }
        #expect(throws: RegionalPlanPriceValidationError.invalidSourceURL) {
            try RegionalPlanPrice(
                key: key,
                money: validMoney,
                billingCycle: .monthly,
                verifiedAt: verifiedAt,
                reviewAfter: reviewAfter,
                sourceURL: httpURL
            )
        }
        #expect(throws: RegionalPlanPriceValidationError.invalidSourceURL) {
            try RegionalPlanPrice(
                key: key,
                money: validMoney,
                billingCycle: .monthly,
                verifiedAt: verifiedAt,
                reviewAfter: reviewAfter,
                sourceURL: relativeURL
            )
        }
        let equalDatesPrice = try RegionalPlanPrice(
            key: key,
            money: validMoney,
            billingCycle: .monthly,
            verifiedAt: reviewAfter,
            reviewAfter: reviewAfter,
            sourceURL: httpsURL
        )
        #expect(equalDatesPrice.verifiedAt == equalDatesPrice.reviewAfter)
        #expect(throws: RegionalPlanPriceValidationError.reviewDateMustNotPrecedeVerificationDate) {
            try RegionalPlanPrice(
                key: key,
                money: validMoney,
                billingCycle: .monthly,
                verifiedAt: reviewAfter,
                reviewAfter: verifiedAt,
                sourceURL: httpsURL
            )
        }
    }

    @Test("Source URL metadata is outside regional price key identity")
    func sourceURLDoesNotChangePriceKeyIdentity() throws {
        let first = try makePrice()
        let alternateURL = try #require(URL(string: "https://another.example.com/plan"))
        let sameKeyWithDifferentSource = try makePrice(sourceURL: alternateURL)

        #expect(first.key == sameKeyWithDifferentSource.key)
        #expect(first.sourceURL != sameKeyWithDifferentSource.sourceURL)
        #expect(throws: RegionalPricingSnapshotValidationError.duplicatePriceKey(first.key)) {
            try makeSnapshot([first, sameKeyWithDifferentSource])
        }
    }

    @Test("Snapshot validates its schema version and revision")
    func snapshotValidation() throws {
        let price = try makePrice()

        #expect(throws: RegionalPricingSnapshotValidationError.invalidSchemaVersion(0)) {
            try RegionalPricingSnapshot(schemaVersion: 0, revision: "v1", prices: [price])
        }
        #expect(throws: RegionalPricingSnapshotValidationError.emptyRevision) {
            try RegionalPricingSnapshot(schemaVersion: 1, revision: "  ", prices: [price])
        }
    }
}
