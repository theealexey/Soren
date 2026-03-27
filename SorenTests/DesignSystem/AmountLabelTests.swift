import Testing
import SwiftUI
@testable import Soren

@Suite("AmountLabel — Currency Formatting")
@MainActor
struct AmountLabelTests {

    // MARK: - Basic formatting

    @Test("Formats whole numbers without fractional part")
    func wholeNumbers() {
        let label = AmountLabel(1000, currency: "RUB")
        #expect(label.amount == 1000)
        #expect(label.currencyCode == "RUB")
    }

    @Test("Preserves exact decimal precision")
    func decimalPrecision() {
        let label = AmountLabel(12.99, currency: "USD")
        #expect(label.amount == 12.99)
    }

    @Test("Handles zero amount")
    func zeroAmount() {
        let label = AmountLabel(0, currency: "RUB")
        #expect(label.amount == 0)
    }

    @Test("Handles very large amounts without overflow")
    func largeAmount() {
        let huge: Decimal = 999_999_999.99
        let label = AmountLabel(huge, currency: "RUB")
        #expect(label.amount == huge)
    }

    @Test("Handles very small fractional amounts")
    func tinyAmount() {
        let label = AmountLabel(0.01, currency: "USD")
        #expect(label.amount == 0.01)
    }

    @Test("Negative amounts are preserved")
    func negativeAmount() {
        let label = AmountLabel(-42.50, currency: "EUR")
        #expect(label.amount == -42.50)
    }

    // MARK: - Currency codes

    @Test("Accepts standard ISO currency codes", arguments: ["RUB", "USD", "EUR", "GBP", "JPY", "CNY", "TRY", "KZT"])
    func standardCurrencies(code: String) {
        let label = AmountLabel(100, currency: code)
        #expect(label.currencyCode == code)
    }

    @Test("Default currency is RUB")
    func defaultCurrency() {
        let label = AmountLabel(100)
        #expect(label.currencyCode == "RUB")
    }

    // MARK: - Cycle labels

    @Test("Monthly cycle label is /мес")
    func monthlyCycle() {
        #expect(AmountLabel.CycleLabel.monthly.label == "/мес")
    }

    @Test("Yearly cycle label is /год")
    func yearlyCycle() {
        #expect(AmountLabel.CycleLabel.yearly.label == "/год")
    }

    @Test("Weekly cycle label is /нед")
    func weeklyCycle() {
        #expect(AmountLabel.CycleLabel.weekly.label == "/нед")
    }

    @Test("Custom cycle label preserves text")
    func customCycle() {
        #expect(AmountLabel.CycleLabel.custom("3mo").label == "/3mo")
    }

    // MARK: - Edge cases

    @Test("Extremely precise decimal doesn't crash")
    func preciseDecimal() {
        let precise: Decimal = Decimal(string: "1234.567890123456")!
        let label = AmountLabel(precise, currency: "USD")
        #expect(label.amount == precise)
    }

    @Test("Maximum Decimal value doesn't crash")
    func maxDecimal() {
        let label = AmountLabel(Decimal.greatestFiniteMagnitude, currency: "USD")
        #expect(label.amount == Decimal.greatestFiniteMagnitude)
    }
}
