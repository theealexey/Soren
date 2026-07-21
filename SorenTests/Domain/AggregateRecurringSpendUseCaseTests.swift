import Foundation
import Testing
@testable import Soren

@Suite("AggregateRecurringSpendUseCase")
struct AggregateRecurringSpendUseCaseTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private var range: Range<Date> {
        start..<start.addingTimeInterval(30 * 24 * 60 * 60)
    }

    private func projection(
        amount: Decimal,
        currency: String,
        dayOffset: Int = 1
    ) -> RecurringSpendProjection {
        RecurringSpendProjection(
            date: start.addingTimeInterval(TimeInterval(dayOffset * 24 * 60 * 60)),
            amount: amount,
            currencyCode: currency
        )
    }

    private func snapshot(
        rates: [String: Decimal] = ["RUB": 90, "EUR": 2],
        freshness: ExchangeRateFreshness = .fresh
    ) -> ExchangeRateSnapshot {
        let fetchedAt = start.addingTimeInterval(-60)
        return ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: start.addingTimeInterval(-3_600),
                rates: rates,
                fetchedAt: fetchedAt
            ),
            freshness: freshness
        )
    }

    @Test("Same-currency values aggregate without an FX snapshot")
    func sameCurrencyDoesNotNeedRates() throws {
        let staleSnapshot = snapshot(freshness: .stale(age: 7_200))
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 100, currency: "RUB"),
                projection(amount: 500, currency: "RUB")
            ],
            reportingCurrencyCode: "RUB",
            snapshot: staleSnapshot,
            range: range
        )

        let total = try #require(result.total)
        #expect(result.isComplete)
        #expect(total == (try Money(amount: 600, currencyCode: "RUB")))
        #expect(result.rateMetadata == nil)
    }

    @Test("Mixed currencies convert before aggregation")
    func mixedCurrenciesConvertBeforeSum() throws {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 100, currency: "USD"),
                projection(amount: 500, currency: "RUB")
            ],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(),
            range: range
        )

        let total = try #require(result.total)
        #expect(result.isComplete)
        #expect(total.amount == 9_500)
        #expect(total.currencyCode == "RUB")
        #expect(total.amount != 600)
        #expect(result.rateMetadata?.freshness == .fresh)
    }

    @Test("Missing one currency produces a partial converted subtotal")
    func missingCurrencyProducesPartial() throws {
        let staleSnapshot = snapshot(freshness: .stale(age: 7_200))
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 500, currency: "RUB"),
                projection(amount: 20, currency: "GBP")
            ],
            reportingCurrencyCode: "RUB",
            snapshot: staleSnapshot,
            range: range
        )

        guard case let .partial(total, missingCodes, metadata) = result else {
            Issue.record("Expected partial aggregation")
            return
        }
        #expect(total.amount == 500)
        #expect(total.currencyCode == "RUB")
        #expect(missingCodes == ["GBP"])
        #expect(metadata == nil)
    }

    @Test("No snapshot never raw-sums foreign and reporting currencies")
    func noSnapshotNeverRawSums() throws {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 100, currency: "USD"),
                projection(amount: 500, currency: "RUB")
            ],
            reportingCurrencyCode: "RUB",
            snapshot: nil,
            range: range
        )

        guard case let .partial(total, missingCodes, metadata) = result else {
            Issue.record("Expected partial aggregation")
            return
        }
        #expect(total.amount == 500)
        #expect(total.amount != 600)
        #expect(missingCodes == ["USD"])
        #expect(metadata == nil)
    }

    @Test("All unconvertible values produce unavailable")
    func allUnconvertibleProducesUnavailable() {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [projection(amount: 100, currency: "USD")],
            reportingCurrencyCode: "RUB",
            snapshot: nil,
            range: range
        )

        guard case let .unavailable(code, missingCodes, reason, metadata) = result else {
            Issue.record("Expected unavailable aggregation")
            return
        }
        #expect(code == "RUB")
        #expect(missingCodes == ["USD"])
        #expect(reason == .noConvertibleAmounts)
        #expect(metadata == nil)
    }

    @Test("Empty range is a complete zero in reporting currency")
    func emptyRangeIsCompleteZero() throws {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(freshness: .stale(age: 7_200)),
            range: range
        )

        let total = try #require(result.total)
        #expect(result.isComplete)
        #expect(total == (try Money(amount: 0, currencyCode: "RUB")))
        #expect(result.rateMetadata == nil)
    }

    @Test("Stale rate metadata survives a successful aggregation")
    func staleMetadataIsPreserved() {
        let age: TimeInterval = 7_200
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [projection(amount: 10, currency: "USD")],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(freshness: .stale(age: age)),
            range: range
        )

        #expect(result.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("A partial stale subtotal retains metadata after a successful foreign contribution")
    func partialStaleAggregationRetainsMetadataAfterSuccessfulConversion() throws {
        let age: TimeInterval = 7_200
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 100, currency: "RUB"),
                projection(amount: 2, currency: "USD"),
                projection(amount: 5, currency: "GBP")
            ],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["RUB": 10], freshness: .stale(age: age)),
            range: range
        )

        guard case let .partial(total, missingCodes, metadata) = result else {
            Issue.record("Expected partial aggregation")
            return
        }
        #expect(total.amount == 120)
        #expect(missingCodes == ["GBP"])
        #expect(metadata?.freshness == .stale(age: age))
    }

    @Test("A successful stale zero conversion remains numeric and carries metadata")
    func staleZeroForeignConversionRemainsAvailable() throws {
        let age: TimeInterval = 7_200
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [projection(amount: 0, currency: "USD")],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["RUB": 90], freshness: .stale(age: age)),
            range: range
        )

        let total = try #require(result.total)
        #expect(result.isComplete)
        #expect(total.amount == 0)
        #expect(result.rateMetadata?.freshness == .stale(age: age))
    }

    @Test("Aggregation preserves original projection values")
    func aggregationPreservesOriginalProjectionValues() {
        let foreign = projection(amount: 12.99, currency: "USD")
        let local = projection(amount: 100, currency: "RUB")

        _ = AggregateRecurringSpendUseCase().execute(
            projections: [foreign, local],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["RUB": 90]),
            range: range
        )

        #expect(foreign.amount == 12.99)
        #expect(foreign.currencyCode == "USD")
        #expect(local.amount == 100)
        #expect(local.currencyCode == "RUB")
    }

    @Test("Only projections inside the requested range are included")
    func dateRangeIsRespected() throws {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [
                projection(amount: 100, currency: "RUB", dayOffset: 1),
                projection(amount: 900, currency: "RUB", dayOffset: 31)
            ],
            reportingCurrencyCode: "RUB",
            snapshot: nil,
            range: range
        )

        #expect(try #require(result.total).amount == 100)
    }

    @Test("Invalid reporting currency is a typed unavailable result")
    func invalidReportingCurrency() {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [projection(amount: 100, currency: "USD")],
            reportingCurrencyCode: "R",
            snapshot: snapshot(),
            range: range
        )

        guard case let .unavailable(code, missingCodes, reason, metadata) = result else {
            Issue.record("Expected unavailable aggregation")
            return
        }
        #expect(code == "R")
        #expect(missingCodes == ["USD"])
        #expect(reason == .invalidReportingCurrencyCode("R"))
        #expect(metadata == nil)
    }

    @Test("A stale snapshot without a convertible amount is unavailable without metadata")
    func missingTargetRate() {
        let result = AggregateRecurringSpendUseCase().execute(
            projections: [projection(amount: 10, currency: "EUR")],
            reportingCurrencyCode: "RUB",
            snapshot: snapshot(rates: ["EUR": 2], freshness: .stale(age: 7_200)),
            range: range
        )

        guard case let .unavailable(_, missingCodes, reason, metadata) = result else {
            Issue.record("Expected unavailable aggregation")
            return
        }
        #expect(missingCodes == ["RUB"])
        #expect(reason == .noConvertibleAmounts)
        #expect(metadata == nil)
    }

    @Test("Rate request detection ignores same-currency and invalid source codes")
    func rateRequestDetection() {
        let useCase = AggregateRecurringSpendUseCase()
        #expect(!useCase.requiresExchangeRates(
            projections: [projection(amount: 100, currency: "RUB")],
            reportingCurrencyCode: "RUB",
            range: range
        ))
        #expect(useCase.requiresExchangeRates(
            projections: [projection(amount: 100, currency: "USD")],
            reportingCurrencyCode: "RUB",
            range: range
        ))
        #expect(!useCase.requiresExchangeRates(
            projections: [projection(amount: 100, currency: "??")],
            reportingCurrencyCode: "RUB",
            range: range
        ))
    }
}
