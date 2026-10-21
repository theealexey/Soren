import Foundation
import SwiftData
import Testing
@testable import Soren

@Suite("Overview fetch and projection baseline")
@MainActor
struct OverviewFetchBaselineTests {
    private static let sizes = [1, 100, 1_000]
    private static let warmupCount = 2
    private static let measuredCount = 5

    private final class CountingRepository: RecurringItemRepository {
        let items: [RecurringItem]
        private(set) var fetchAllCalls = 0
        private(set) var returnedItemCounts: [Int] = []

        init(items: [RecurringItem]) { self.items = items }

        func resetMeasurements() {
            fetchAllCalls = 0
            returnedItemCounts = []
        }

        func fetchAll() throws -> [RecurringItem] {
            fetchAllCalls += 1
            returnedItemCounts.append(items.count)
            return items
        }

        func fetchActive() throws -> [RecurringItem] { items.filter(\.status.countsInTotals) }
        func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { items }
        func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
            items.filter { $0.category == category }
        }
        func fetch(id: UUID) throws -> RecurringItem? { items.first { $0.id == id } }
        func save(_ item: RecurringItem) throws { throw UnsupportedOperation.error }
        func update(_ item: RecurringItem) throws { throw UnsupportedOperation.error }
        func delete(id: UUID) throws { throw UnsupportedOperation.error }
        func saveAll(_ items: [RecurringItem]) throws { throw UnsupportedOperation.error }
        func deleteAll() throws { throw UnsupportedOperation.error }
    }

    private enum UnsupportedOperation: Error { case error }
    private enum UnavailableRate: Error { case unavailable }

    private actor UnavailableRates: ExchangeRateProvider {
        func latestSnapshot() async throws -> ExchangeRateSnapshot {
            throw UnavailableRate.unavailable
        }
    }

    @Test("Measures HomeViewModel orchestration with an in-memory counting repository")
    func overviewOrchestration() async throws {
        let calendar = Self.gregorianCalendar
        let today = try Self.canonicalDate(year: 2026, month: 10, day: 21)

        for size in Self.sizes {
            let repository = CountingRepository(items: try Self.items(count: size))
            let planUseCase = CurrentMonthSubscriptionPlanUseCase(repository: repository)
            let insightUseCase = OverviewInsightUseCase(repository: repository)
            let (preferences, defaults, suiteName) = try Self.preferences()
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let viewModel = HomeViewModel(
                getUpcomingCharges: GetUpcomingCharges(repository: repository),
                preferences: preferences,
                exchangeRateProvider: UnavailableRates(),
                calculateCurrentMonth: { date, calendar, currency, rates in
                    try await planUseCase.executeSnapshot(
                        today: date,
                        calendar: calendar,
                        reportingCurrencyCode: currency,
                        exchangeRateSnapshot: rates
                    )
                },
                calculateOverviewInsight: { date, calendar, currency, rates in
                    try await insightUseCase.execute(
                        today: date,
                        calendar: calendar,
                        reportingCurrencyCode: currency,
                        exchangeRateSnapshot: rates
                    )
                },
                now: { today },
                calendar: calendar,
                timeZone: { calendar.timeZone }
            )

            for _ in 0..<Self.warmupCount {
                repository.resetMeasurements()
                await viewModel.load(forceReload: true)
            }

            var samples: [Double] = []
            var measuredFetchCounts: [Int] = []
            var returnedCounts: [Int] = []
            for _ in 0..<Self.measuredCount {
                repository.resetMeasurements()
                let clock = ContinuousClock()
                let start = clock.now
                await viewModel.load(forceReload: true)
                let elapsed = start.duration(to: clock.now)
                samples.append(Self.milliseconds(elapsed))
                measuredFetchCounts.append(repository.fetchAllCalls)
                returnedCounts.append(repository.returnedItemCounts.reduce(0, +))
            }

            #expect(measuredFetchCounts == Array(repeating: 3, count: Self.measuredCount))
            #expect(returnedCounts == Array(repeating: size * 3, count: Self.measuredCount))
            #expect(viewModel.isLoaded)
            Self.report(
                "overview-test-double",
                size: size,
                samples: samples,
                detail: "fetchAll/load=3; returned/load=\(size * 3); source-derived projector calls/load=\(size * 2)"
            )
        }
    }

    @Test("Measures SwiftData fetch, mapping, and canonical sorting in an ephemeral container")
    func swiftDataFetchMaterialization() throws {
        for size in Self.sizes {
            let container = try SorenModelContainer.inMemory()
            let repository = SwiftDataRecurringItemRepository(container: container)
            let items = try Self.items(count: size)
            try repository.saveAll(items)

            for _ in 0..<Self.warmupCount {
                #expect(try repository.fetchAll().count == size)
            }

            var samples: [Double] = []
            for _ in 0..<Self.measuredCount {
                let clock = ContinuousClock()
                let start = clock.now
                let fetched = try repository.fetchAll()
                let elapsed = start.duration(to: clock.now)
                #expect(fetched.count == size)
                samples.append(Self.milliseconds(elapsed))
            }

            Self.report("swiftdata-fetch-map-sort", size: size, samples: samples)
        }
    }

    private static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private static func canonicalDate(year: Int, month: Int, day: Int) throws -> Date {
        try BillingCivilDay.canonicalDate(for: CivilDate(year: year, month: month, day: day))
    }

    private static func stableUUID(for index: Int) -> UUID {
        let value = UInt64(index + 1)
        return UUID(uuid: (
            0, 0, 0, 0, 0, 0, 0, 0,
            UInt8((value >> 56) & 0xff),
            UInt8((value >> 48) & 0xff),
            UInt8((value >> 40) & 0xff),
            UInt8((value >> 32) & 0xff),
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ))
    }

    private static func items(count: Int) throws -> [RecurringItem] {
        let start = try canonicalDate(year: 2025, month: 1, day: 1)
        let end = try canonicalDate(year: 2027, month: 12, day: 31)
        let trialEnd = try canonicalDate(year: 2026, month: 11, day: 5)

        return try (0..<count).map { index in
            let day = index % 28 + 1
            let anchor = try canonicalDate(year: 2026, month: 11, day: day)
            let status: ItemStatus
            switch index % 8 {
            case 0: status = .trial
            case 1: status = .paused
            case 2: status = .overdue
            case 3: status = .failed
            case 4: status = .cancelled
            case 5: status = .dueSoon
            case 6: status = .dueToday
            default: status = .active
            }
            let cycle: BillingCycle
            switch index % 4 {
            case 0: cycle = .monthly
            case 1: cycle = .annual
            case 2: cycle = .quarterly
            default: cycle = .weekly
            }
            let archived = index % 17 == 0
            let finite = index % 11 == 0
            let id = Self.stableUUID(for: index)
            return RecurringItem(
                id: id,
                title: "Perf item \(index)",
                providerID: "perf-provider-\(index % 12)",
                providerName: "Performance provider \(index % 12)",
                amount: Decimal(index % 200 + 1),
                currencyCode: "RUB",
                billingCycle: cycle,
                startDate: start,
                nextChargeDate: anchor,
                trialEndDate: status == .trial ? trialEnd : nil,
                autoRenew: !finite,
                endDate: finite ? end : nil,
                status: archived ? .archived : status,
                createdAt: start,
                updatedAt: start,
                archivedAt: archived ? start : nil
            )
        }
    }

    private static func preferences() throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suiteName = "OverviewFetchBaselineTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let repository = UserPreferencesRepository(defaults: defaults)
        repository.save(UserPreferences(
            defaultCurrencyCode: "RUB",
            defaultChargeReminder: .threeDaysBefore,
            chargeAlertDays: 3,
            trialAlertDays: 3
        ))
        return (repository, defaults, suiteName)
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private static func report(_ name: String, size: Int, samples: [Double], detail: String = "") {
        let sorted = samples.sorted()
        let median = sorted[sorted.count / 2]
        let spread = (sorted.last ?? .zero) - (sorted.first ?? .zero)
        print("SOR_PERF_BASELINE name=\(name) items=\(size) warmups=\(warmupCount) samples_ms=\(samples) median_ms=\(median) range_ms=\(spread) \(detail)")
    }
}
