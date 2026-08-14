import Foundation

// MARK: - AppContainer + Home Factory

extension AppContainer {
    func makeHomeViewModel() -> HomeViewModel {
        let repositoryBridge = HomeRecurringItemRepositoryBridge(
            base: repositories.recurringItems
        )
        let planUseCase = CurrentMonthSubscriptionPlanUseCase(repository: repositoryBridge)
        let insightUseCase = OverviewInsightUseCase(repository: repositoryBridge)

        let planCalculation: MonthlySubscriptionPlanCalculation = {
            today,
            calendar,
            reportingCurrencyCode,
            exchangeRateSnapshot in
            try await planUseCase.execute(
                today: today,
                calendar: calendar,
                reportingCurrencyCode: reportingCurrencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot
            )
        }
        let insightCalculation: OverviewInsightCalculation = {
            today,
            calendar,
            reportingCurrencyCode,
            exchangeRateSnapshot in
            try await insightUseCase.execute(
                today: today,
                calendar: calendar,
                reportingCurrencyCode: reportingCurrencyCode,
                exchangeRateSnapshot: exchangeRateSnapshot
            )
        }

        #if DEBUG
        let runtimeScenario = DebugHomeScenario.requested(
            in: ProcessInfo.processInfo.arguments
        )
        let now: @Sendable () -> Date = {
            runtimeScenario?.referenceDate ?? .now
        }
        let calendar = runtimeScenario?.calendar ?? .current
        #else
        let now: @Sendable () -> Date = { .now }
        let calendar = Calendar.current
        #endif

        return HomeViewModel(
            getUpcomingCharges: GetUpcomingCharges(repository: repositories.recurringItems),
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: exchangeRateProvider,
            calculateMonthlyPlan: planCalculation,
            calculateOverviewInsight: insightCalculation,
            now: now,
            calendar: calendar
        )
    }
}

/// Bridges the composition root's repository existential into the generic,
/// Sendable Domain use cases without changing the repository contract.
@MainActor
private final class HomeRecurringItemRepositoryBridge: RecurringItemRepository {
    private let base: any RecurringItemRepository

    init(base: any RecurringItemRepository) {
        self.base = base
    }

    func fetchAll() throws -> [RecurringItem] { try base.fetchAll() }
    func fetchActive() throws -> [RecurringItem] { try base.fetchActive() }

    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
        try base.fetchUpcoming(within: days, from: date)
    }

    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        try base.fetchByCategory(category)
    }

    func fetch(id: UUID) throws -> RecurringItem? { try base.fetch(id: id) }
    func save(_ item: RecurringItem) throws { try base.save(item) }
    func update(_ item: RecurringItem) throws { try base.update(item) }
    func delete(id: UUID) throws { try base.delete(id: id) }
    func saveAll(_ items: [RecurringItem]) throws { try base.saveAll(items) }
    func deleteAll() throws { try base.deleteAll() }
}

#if DEBUG
/// Coherent, in-memory runtime scenarios. AppState installs the complete item
/// set through the normal repository boundary before Home is constructed.
enum DebugHomeScenario: String, Sendable {
    case annualScale
    case attention
    case denseWeek
    case emptyUpcoming
    case partialRemaining

    static func requested(in arguments: [String]) -> Self? {
        if arguments.contains("--home-scenario-annual") { return .annualScale }
        if arguments.contains("--home-scenario-attention") { return .attention }
        if arguments.contains("--home-scenario-dense-week") { return .denseWeek }
        if arguments.contains("--home-scenario-empty") { return .emptyUpcoming }
        if arguments.contains("--home-scenario-partial-remaining") { return .partialRemaining }
        return nil
    }

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }

    var referenceDate: Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 13,
            hour: 12
        )) ?? Date(timeIntervalSince1970: 1_786_610_400)
    }

    var items: [RecurringItem] {
        switch self {
        case .annualScale:
            return [
                item(
                    id: 1,
                    title: "Spotify Индивидуальный",
                    providerID: "spotify",
                    providerName: "Spotify",
                    category: .music,
                    amount: 199,
                    day: 15
                ),
                item(
                    id: 2,
                    title: "YouTube Premium Индивидуальный",
                    providerID: "youtube_premium",
                    providerName: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    day: 21
                ),
                item(
                    id: 3,
                    title: "iCloud+ 200 ГБ",
                    providerID: "icloud",
                    providerName: "iCloud+",
                    category: .cloud,
                    amount: 299,
                    day: 28
                ),
            ]

        case .attention:
            return [
                item(
                    id: 11,
                    title: "Apple Music",
                    providerID: "apple_music",
                    providerName: "Apple Music",
                    category: .music,
                    amount: 169,
                    day: 16,
                    status: .trial,
                    trialEndDay: 16
                ),
                item(
                    id: 12,
                    title: "YouTube Premium Индивидуальный",
                    providerID: "youtube_premium",
                    providerName: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    day: 21
                ),
                item(
                    id: 13,
                    title: "iCloud+ 200 ГБ",
                    providerID: "icloud",
                    providerName: "iCloud+",
                    category: .cloud,
                    amount: 299,
                    day: 28
                ),
            ]

        case .denseWeek:
            return [
                item(
                    id: 21,
                    title: "Spotify Индивидуальный",
                    providerID: "spotify",
                    providerName: "Spotify",
                    category: .music,
                    amount: 199,
                    day: 15
                ),
                item(
                    id: 22,
                    title: "YouTube Premium Индивидуальный",
                    providerID: "youtube_premium",
                    providerName: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    day: 18
                ),
                item(
                    id: 23,
                    title: "iCloud+ 200 ГБ",
                    providerID: "icloud",
                    providerName: "iCloud+",
                    category: .cloud,
                    amount: 299,
                    day: 20
                ),
            ]

        case .emptyUpcoming:
            return []

        case .partialRemaining:
            return [
                item(
                    id: 31,
                    title: "Spotify Индивидуальный",
                    providerID: "spotify",
                    providerName: "Spotify",
                    category: .music,
                    amount: 199,
                    day: 11
                ),
                item(
                    id: 32,
                    title: "YouTube Premium Индивидуальный",
                    providerID: "youtube_premium",
                    providerName: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    day: 21
                ),
                item(
                    id: 33,
                    title: "iCloud+ 200 ГБ",
                    providerID: "icloud",
                    providerName: "iCloud+",
                    category: .cloud,
                    amount: 299,
                    day: 28
                ),
            ]
        }
    }

    private func item(
        id: UInt8,
        title: String,
        providerID: String,
        providerName: String,
        category: ItemCategory,
        amount: Decimal,
        day: Int,
        status: ItemStatus = .active,
        trialEndDay: Int? = nil
    ) -> RecurringItem {
        let chargeDate = date(day: day)
        let trialEndDate = trialEndDay.map { date(day: $0) }
        let startDate = calendar.date(byAdding: .month, value: -4, to: chargeDate) ?? chargeDate

        return RecurringItem(
            id: Self.id(id),
            title: title,
            providerID: providerID,
            providerName: providerName,
            category: category,
            amount: amount,
            currencyCode: "RUB",
            billingCycle: .monthly,
            startDate: startDate,
            nextChargeDate: chargeDate,
            trialEndDate: trialEndDate,
            status: status,
            tags: ["overview-runtime-scenario"]
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: day,
            hour: 12
        )) ?? referenceDate
    }

    private static func id(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }
}
#endif
