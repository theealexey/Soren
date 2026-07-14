import Foundation

// MARK: - Conversion Result

struct ConversionResult: Equatable, Sendable {
    let original: Money
    let converted: Money
    let rateDate: Date
    let ratesFetchedAt: Date
    let freshness: ExchangeRateFreshness
}

enum ConvertMoneyError: Error, Equatable, Sendable {
    case invalidTargetCurrencyCode(String)
    case missingSourceRate(String)
    case missingTargetRate(String)
    case invalidRate(String)
}

// MARK: - Convert Money

/// The single Domain conversion policy. It never mutates or rounds the original money.
struct ConvertMoneyUseCase: Sendable {
    func execute(
        original: Money,
        targetCurrencyCode: String,
        snapshot: ExchangeRateSnapshot
    ) throws -> ConversionResult {
        let targetCode: String
        do {
            targetCode = try Money.normalizeCurrencyCode(targetCurrencyCode)
        } catch {
            throw ConvertMoneyError.invalidTargetCurrencyCode(targetCurrencyCode)
        }

        let convertedAmount: Decimal
        if original.currencyCode == targetCode {
            convertedAmount = original.amount
        } else {
            let rates = snapshot.exchangeRates
            let sourceRate = try rate(
                for: original.currencyCode,
                in: rates,
                missingError: .missingSourceRate(original.currencyCode)
            )
            let targetRate = try rate(
                for: targetCode,
                in: rates,
                missingError: .missingTargetRate(targetCode)
            )
            convertedAmount = original.amount * targetRate / sourceRate
        }

        let converted = try Money(amount: convertedAmount, currencyCode: targetCode)
        return ConversionResult(
            original: original,
            converted: converted,
            rateDate: snapshot.providerDate,
            ratesFetchedAt: snapshot.fetchedAt,
            freshness: snapshot.freshness
        )
    }

    private func rate(
        for currencyCode: String,
        in rates: ExchangeRates,
        missingError: ConvertMoneyError
    ) throws -> Decimal {
        let value: Decimal
        if currencyCode == rates.base {
            value = 1
        } else {
            guard let storedRate = rates.rates[currencyCode] else {
                throw missingError
            }
            value = storedRate
        }

        guard value > 0 else {
            throw ConvertMoneyError.invalidRate(currencyCode)
        }
        return value
    }
}
