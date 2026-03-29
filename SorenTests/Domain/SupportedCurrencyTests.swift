import Testing
import Foundation
@testable import Soren

// MARK: - Supported Currency Catalog Tests (Adversarial)

/// Validates the currency catalog for data integrity:
/// duplicate codes, ISO compliance, and decimal consistency.

@Suite("SupportedCurrency")
struct SupportedCurrencyTests {

    @Test("Catalog is non-empty")
    func nonEmpty() {
        #expect(!SupportedCurrency.all.isEmpty)
        #expect(SupportedCurrency.all.count >= 10)
    }

    @Test("All codes are unique — no duplicates")
    func uniqueCodes() {
        let codes = SupportedCurrency.all.map(\.code)
        let unique = Set(codes)
        #expect(codes.count == unique.count, "Duplicate currency codes found")
    }

    @Test("All codes are 3 uppercase letters (ISO 4217)")
    func iso4217Format() {
        let pattern = /^[A-Z]{3}$/
        for currency in SupportedCurrency.all {
            #expect(currency.code.wholeMatch(of: pattern) != nil,
                    "\(currency.code) is not a valid ISO 4217 code")
        }
    }

    @Test("codes array matches all.map(code) — no drift")
    func codesArrayInSync() {
        #expect(SupportedCurrency.codes == SupportedCurrency.all.map(\.code))
    }

    @Test("JPY has 0 decimal places (zero-decimal currency)")
    func jpyDecimalPlaces() {
        let jpy = SupportedCurrency.all.first { $0.code == "JPY" }
        #expect(jpy != nil, "JPY must be in catalog")
        #expect(jpy?.decimalPlaces == 0)
    }

    @Test("All non-JPY currencies have 2 decimal places")
    func standardDecimalPlaces() {
        for currency in SupportedCurrency.all where currency.code != "JPY" {
            #expect(currency.decimalPlaces == 2,
                    "\(currency.code) should have 2 decimal places, got \(currency.decimalPlaces)")
        }
    }

    @Test("Every entry has non-empty symbol and name")
    func nonEmptyFields() {
        for currency in SupportedCurrency.all {
            #expect(!currency.symbol.isEmpty, "\(currency.code) has empty symbol")
            #expect(!currency.name.isEmpty, "\(currency.code) has empty name")
        }
    }

    @Test("ID matches code (Identifiable conformance)")
    func idMatchesCode() {
        for currency in SupportedCurrency.all {
            #expect(currency.id == currency.code)
        }
    }

    @Test("Key RU-market currencies are present")
    func ruMarketCurrencies() {
        let codes = Set(SupportedCurrency.codes)
        let required = ["RUB", "USD", "EUR", "TRY", "KZT", "BYN", "GEL", "AMD", "AED"]
        for code in required {
            #expect(codes.contains(code), "\(code) missing from catalog — critical for RU market")
        }
    }
}
