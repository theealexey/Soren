import Foundation

// MARK: - Currency Estimate Request

/// Validated input for a derived reporting-currency estimate.
/// The original money remains immutable and authoritative.
struct CurrencyEstimateRequest: Equatable, Sendable {
    let original: Money
    let targetCurrencyCode: String

    init(
        amount: Decimal,
        originalCurrencyCode: String,
        targetCurrencyCode: String
    ) throws {
        self.original = try Money(amount: amount, currencyCode: originalCurrencyCode)
        self.targetCurrencyCode = try Money.normalizeCurrencyCode(targetCurrencyCode)
    }

    var requiresConversion: Bool {
        original.currencyCode != targetCurrencyCode
    }
}

// MARK: - Currency Estimate State

/// Presentation state shared by Add and Edit forms.
/// No case can mutate or replace the original subscription amount.
enum CurrencyEstimateState: Equatable, Sendable {
    case hidden
    case loading
    case available(ConversionResult)
    case unavailable

    var isVisible: Bool {
        switch self {
        case .available, .unavailable:
            true
        case .hidden, .loading:
            false
        }
    }
}

// MARK: - Currency Estimate Service

/// Narrow application-layer bridge between the actor-isolated rate provider
/// and the shared Domain conversion policy.
struct CurrencyEstimateService: Sendable {
    private let loadLatestSnapshot: @Sendable () async throws -> ExchangeRateSnapshot
    private let convertMoney: ConvertMoneyUseCase

    init<Provider: ExchangeRateProvider>(
        exchangeRateProvider: Provider,
        convertMoney: ConvertMoneyUseCase
    ) {
        self.loadLatestSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
        self.convertMoney = convertMoney
    }

    func estimate(_ request: CurrencyEstimateRequest) async throws -> ConversionResult {
        let snapshot = try await loadLatestSnapshot()
        return try convertMoney.execute(
            original: request.original,
            targetCurrencyCode: request.targetCurrencyCode,
            snapshot: snapshot
        )
    }

    static let preview = CurrencyEstimateService(
        exchangeRateProvider: StaticExchangeRateProvider(),
        convertMoney: ConvertMoneyUseCase()
    )
}
