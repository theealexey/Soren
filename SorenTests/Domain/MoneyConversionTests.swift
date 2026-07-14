import Foundation
import Testing
@testable import Soren

@Suite("Money and conversion")
struct MoneyConversionTests {
    private let rateDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let fetchedAt = Date(timeIntervalSince1970: 1_700_000_100)

    private func decimal(_ value: String) throws -> Decimal {
        try #require(Decimal(string: value))
    }

    private func snapshot(
        rates: [String: Decimal],
        freshness: ExchangeRateFreshness = .fresh
    ) -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: rateDate,
                rates: rates,
                fetchedAt: fetchedAt
            ),
            freshness: freshness
        )
    }

    @Test("Money preserves exact Decimal and normalizes currency code")
    func moneyPreservesExactValue() throws {
        let amount = try decimal("12.34567890123456789")
        let money = try Money(amount: amount, currencyCode: " usd ")

        #expect(money.amount == amount)
        #expect(money.currencyCode == "USD")
    }

    @Test("Money rejects malformed currency codes")
    func moneyRejectsMalformedCode() {
        #expect(throws: MoneyValidationError.invalidCurrencyCode("US")) {
            try Money(amount: 1, currencyCode: "US")
        }
        #expect(throws: MoneyValidationError.invalidCurrencyCode("R₽B")) {
            try Money(amount: 1, currencyCode: "R₽B")
        }
    }

    @Test("Same currency preserves the amount without requiring a rate")
    func sameCurrencyIsExact() throws {
        let original = try Money(amount: decimal("0.000000123456"), currencyCode: "RUB")
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "rub",
            snapshot: snapshot(rates: [:])
        )

        #expect(result.original == original)
        #expect(result.converted == original)
    }

    @Test("USD to RUB uses the direct base rate")
    func usdToRub() throws {
        let original = try Money(amount: 12, currencyCode: "USD")
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["RUB": decimal("87.5")])
        )
        let expected = try decimal("1050")

        #expect(result.converted.amount == expected)
        #expect(result.converted.currencyCode == "RUB")
        #expect(result.original == original)
    }

    @Test("Non-base conversion uses the cross-rate formula")
    func crossRate() throws {
        let original = try Money(amount: 10, currencyCode: "EUR")
        let eurRate = try decimal("0.92")
        let rubRate = try decimal("87.5")
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["EUR": eurRate, "RUB": rubRate])
        )

        #expect(result.converted.amount == Decimal(10) * rubRate / eurRate)
        #expect(result.original == original)
    }

    @Test("Domain conversion does not round the result")
    func conversionDoesNotRound() throws {
        let original = try Money(amount: 1, currencyCode: "EUR")
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["EUR": 3, "RUB": 10])
        )
        let rounded = try decimal("3.33")

        #expect(result.converted.amount == Decimal(10) / Decimal(3))
        #expect(result.converted.amount != rounded)
    }

    @Test("Missing source rate is a typed failure")
    func missingSourceRate() throws {
        let original = try Money(amount: 10, currencyCode: "EUR")

        #expect(throws: ConvertMoneyError.missingSourceRate("EUR")) {
            try ConvertMoneyUseCase().execute(
                original: original,
                targetCurrencyCode: "RUB",
                snapshot: snapshot(rates: ["RUB": 90])
            )
        }
    }

    @Test("Missing target rate is a typed failure")
    func missingTargetRate() throws {
        let original = try Money(amount: 10, currencyCode: "EUR")

        #expect(throws: ConvertMoneyError.missingTargetRate("RUB")) {
            try ConvertMoneyUseCase().execute(
                original: original,
                targetCurrencyCode: "RUB",
                snapshot: snapshot(rates: ["EUR": 0.9])
            )
        }
    }

    @Test("Conversion result carries rate timestamps and freshness")
    func resultCarriesSnapshotMetadata() throws {
        let original = try Money(amount: 1, currencyCode: "USD")
        let freshness = ExchangeRateFreshness.stale(age: 25_200)
        let result = try ConvertMoneyUseCase().execute(
            original: original,
            targetCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["RUB": 90], freshness: freshness)
        )

        #expect(result.rateDate == rateDate)
        #expect(result.ratesFetchedAt == fetchedAt)
        #expect(result.freshness == freshness)
    }
}
