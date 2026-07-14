import Foundation

// MARK: - Money

/// Immutable monetary value in its original currency.
/// Domain calculations preserve full `Decimal` precision and never format or round.
struct Money: Equatable, Sendable {
    let amount: Decimal
    let currencyCode: String

    init(amount: Decimal, currencyCode: String) throws {
        self.amount = amount
        self.currencyCode = try Self.normalizeCurrencyCode(currencyCode)
    }

    static func normalizeCurrencyCode(_ code: String) throws -> String {
        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let bytes = normalized.utf8
        let isThreeUppercaseASCIILetters = bytes.count == 3
            && bytes.allSatisfy { (65...90).contains($0) }

        guard isThreeUppercaseASCIILetters else {
            throw MoneyValidationError.invalidCurrencyCode(code)
        }

        return normalized
    }
}

enum MoneyValidationError: Error, Equatable, Sendable {
    case invalidCurrencyCode(String)
}
