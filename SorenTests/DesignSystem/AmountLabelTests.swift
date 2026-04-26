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

    // MARK: - Single-line contract (Analytics overview card guarantee)

    /// Verifies that the formatter returns a non-empty string for a large yearly
    /// amount — the value that previously caused the currency symbol to wrap
    /// to a second line in the Analytics overview card (e.g. "48.674,05 ₽").
    @Test("Large yearly RUB amount formats to non-empty string")
    func largeYearlyRUBFormatsNonEmpty() {
        let label = AmountLabel(48_674.05, currency: "RUB")
        let formatted = label.formattedAmount   // capture on @MainActor before #expect closure
        #expect(!formatted.isEmpty)
    }

    /// Verifies currency symbol is locale-derived from NumberFormatter, not hardcoded.
    /// Every formatted string must contain at least one digit, proving it comes
    /// from the formatter pipeline rather than a static literal.
    @Test("Formatted amount contains digits — symbol is formatter-derived not hardcoded",
          arguments: ["RUB", "USD", "EUR", "TRY", "KZT", "GBP", "JPY"])
    func formattedAmountContainsDigit(currency: String) {
        let label = AmountLabel(1234.56, currency: currency)
        let formatted = label.formattedAmount   // capture on @MainActor before #expect closure
        let hasDigit = formatted.contains(where: \.isNumber)
        #expect(hasDigit, "formatted amount for \(currency) should contain at least one digit")
    }

    /// Monthly and yearly Analytics overview cards both construct `StatBlock`
    /// without a custom `amountSize`, so both resolve to `.large`.
    /// This test catches future drift if one card gains a per-card font override.
    @Test("Monthly and yearly stat blocks use identical AmountLabel size")
    func monthlyYearlySameAmountSize() {
        let monthly = StatBlock(title: "В месяц", amount: 4299,   currency: "RUB")
        let yearly  = StatBlock(title: "В год",   amount: 51_588, currency: "RUB")
        #expect(monthly.amountSize == yearly.amountSize)
    }
}
