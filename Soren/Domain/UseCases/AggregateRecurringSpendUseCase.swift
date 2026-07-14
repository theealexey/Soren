import Foundation

// MARK: - Recurring Spend Projection

/// One dated charge amount in its original, authoritative currency.
/// Callers may project persisted recurring items into this value without mutating them.
struct RecurringSpendProjection: Equatable, Sendable {
    let date: Date
    let amount: Decimal
    let currencyCode: String
}

// MARK: - Aggregation Result

/// Exchange-rate metadata retained when FX participates in an aggregation.
struct SpendAggregationRateMetadata: Equatable, Sendable {
    let providerDate: Date
    let fetchedAt: Date
    let freshness: ExchangeRateFreshness

    init(snapshot: ExchangeRateSnapshot) {
        self.providerDate = snapshot.providerDate
        self.fetchedAt = snapshot.fetchedAt
        self.freshness = snapshot.freshness
    }
}

enum SpendAggregationUnavailableReason: Equatable, Sendable {
    case invalidReportingCurrencyCode(String)
    case noConvertibleAmounts
}

/// A total in one reporting currency. Raw cross-currency fallback is impossible by construction.
enum RecurringSpendAggregationResult: Equatable, Sendable {
    case complete(
        total: Money,
        rateMetadata: SpendAggregationRateMetadata?
    )
    case partial(
        total: Money,
        missingCurrencyCodes: [String],
        rateMetadata: SpendAggregationRateMetadata?
    )
    case unavailable(
        reportingCurrencyCode: String,
        missingCurrencyCodes: [String],
        reason: SpendAggregationUnavailableReason,
        rateMetadata: SpendAggregationRateMetadata?
    )

    var total: Money? {
        switch self {
        case let .complete(total, _), let .partial(total, _, _):
            total
        case .unavailable:
            nil
        }
    }

    var missingCurrencyCodes: [String] {
        switch self {
        case .complete:
            []
        case let .partial(_, codes, _), let .unavailable(_, codes, _, _):
            codes
        }
    }

    var rateMetadata: SpendAggregationRateMetadata? {
        switch self {
        case let .complete(_, metadata),
             let .partial(_, _, metadata),
             let .unavailable(_, _, _, metadata):
            metadata
        }
    }

    var isComplete: Bool {
        if case .complete = self { return true }
        return false
    }
}

// MARK: - Aggregate Recurring Spend

/// Canonical Domain policy for summing recurring charges in one reporting currency.
///
/// Same-currency values never require rates. Foreign values are included only after a
/// successful `ConvertMoneyUseCase` conversion. Missing rates therefore produce a typed
/// partial/unavailable result instead of a numerically plausible but meaningless raw sum.
struct AggregateRecurringSpendUseCase: Sendable {
    private let convertMoney: ConvertMoneyUseCase

    init(convertMoney: ConvertMoneyUseCase = ConvertMoneyUseCase()) {
        self.convertMoney = convertMoney
    }

    func execute(
        projections: [RecurringSpendProjection],
        reportingCurrencyCode: String,
        snapshot: ExchangeRateSnapshot?,
        range: Range<Date>
    ) -> RecurringSpendAggregationResult {
        let scoped = projections.filter { range.contains($0.date) }

        guard let targetCode = try? Money.normalizeCurrencyCode(reportingCurrencyCode),
              let zero = try? Money(amount: .zero, currencyCode: reportingCurrencyCode)
        else {
            return .unavailable(
                reportingCurrencyCode: reportingCurrencyCode,
                missingCurrencyCodes: uniqueCodes(from: scoped),
                reason: .invalidReportingCurrencyCode(reportingCurrencyCode),
                rateMetadata: nil
            )
        }

        guard !scoped.isEmpty else {
            return .complete(total: zero, rateMetadata: nil)
        }

        var convertedTotal = Decimal.zero
        var validAmountCount = 0
        var missingCodes = Set<String>()
        var usedForeignCurrency = false

        for projection in scoped {
            guard let original = try? Money(
                amount: projection.amount,
                currencyCode: projection.currencyCode
            ) else {
                missingCodes.insert(displayCode(projection.currencyCode))
                continue
            }

            if original.currencyCode == targetCode {
                convertedTotal += original.amount
                validAmountCount += 1
                continue
            }

            usedForeignCurrency = true
            guard let snapshot else {
                missingCodes.insert(original.currencyCode)
                continue
            }

            do {
                let conversion = try convertMoney.execute(
                    original: original,
                    targetCurrencyCode: targetCode,
                    snapshot: snapshot
                )
                convertedTotal += conversion.converted.amount
                validAmountCount += 1
            } catch let error as ConvertMoneyError {
                switch error {
                case let .missingSourceRate(code), let .invalidRate(code):
                    missingCodes.insert(code)
                case let .missingTargetRate(code), let .invalidTargetCurrencyCode(code):
                    missingCodes.insert(code)
                }
            } catch {
                missingCodes.insert(original.currencyCode)
            }
        }

        let sortedMissingCodes = missingCodes.sorted()
        let metadata = usedForeignCurrency
            ? snapshot.map(SpendAggregationRateMetadata.init(snapshot:))
            : nil

        guard validAmountCount > 0,
              let total = try? Money(amount: convertedTotal, currencyCode: targetCode)
        else {
            return .unavailable(
                reportingCurrencyCode: targetCode,
                missingCurrencyCodes: sortedMissingCodes,
                reason: .noConvertibleAmounts,
                rateMetadata: metadata
            )
        }

        if sortedMissingCodes.isEmpty {
            return .complete(total: total, rateMetadata: metadata)
        }

        return .partial(
            total: total,
            missingCurrencyCodes: sortedMissingCodes,
            rateMetadata: metadata
        )
    }

    func requiresExchangeRates(
        projections: [RecurringSpendProjection],
        reportingCurrencyCode: String,
        range: Range<Date>
    ) -> Bool {
        guard let targetCode = try? Money.normalizeCurrencyCode(reportingCurrencyCode) else {
            return false
        }

        return projections
            .filter { range.contains($0.date) }
            .contains { projection in
                guard let sourceCode = try? Money.normalizeCurrencyCode(projection.currencyCode) else {
                    return false
                }
                return sourceCode != targetCode
            }
    }

    private func uniqueCodes(from projections: [RecurringSpendProjection]) -> [String] {
        Set(projections.map { displayCode($0.currencyCode) }).sorted()
    }

    private func displayCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
