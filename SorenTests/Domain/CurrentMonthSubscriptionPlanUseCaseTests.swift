import Foundation
import Testing
@testable import Soren

@Suite("CurrentMonthSubscriptionPlanUseCase")
struct CurrentMonthSubscriptionPlanUseCaseTests {
    private var calendar: Calendar {
        fixedCalendar(timeZoneID: "UTC")
    }

    private var today: Date {
        date(2026, 8, 13, hour: 10, calendar: calendar)
    }

    // MARK: - Month Boundaries

    @Test("August uses a half-open calendar-month interval")
    func augustInterval() async throws {
        let plan = try #require(await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: date(2026, 8, 31)),
            item(id: 2, amount: 900, nextChargeDate: date(2026, 9, 1), billingCycle: .annual)
        ]))

        #expect(plan.plannedTotal.amount == 100)
        #expect(plan.chargeCount == 1)
    }

    @Test("December does not include an occurrence on January first")
    func decemberToJanuaryBoundary() async throws {
        let localToday = date(2026, 12, 20)
        let plan = try #require(await execute(
            items: [item(id: 1, nextChargeDate: date(2027, 1, 1), billingCycle: .annual)],
            today: localToday
        ))

        #expect(plan.chargeCount == 0)
        #expect(plan.plannedTotal.amount == 0)
    }

    @Test("Non-leap February projects only dates inside February")
    func februaryBoundary() async throws {
        let localToday = date(2027, 2, 10)
        let plan = try #require(await execute(
            items: [item(
                id: 1,
                amount: 10,
                nextChargeDate: date(2027, 2, 1),
                billingCycle: .custom(days: 7),
                startDate: date(2027, 1, 1)
            )],
            today: localToday
        ))

        #expect(plan.chargeCount == 4)
        #expect(plan.plannedTotal.amount == 40)
    }

    @Test("Leap February includes February twenty-ninth")
    func leapFebruaryBoundary() async throws {
        let localToday = date(2028, 2, 10)
        let plan = try #require(await execute(
            items: [item(
                id: 1,
                amount: 25,
                nextChargeDate: date(2028, 2, 29),
                billingCycle: .annual,
                startDate: date(2020, 2, 29)
            )],
            today: localToday
        ))

        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 25)
    }

    // MARK: - Recurrence Projection

    @Test("Monthly recurrence contributes one occurrence")
    func monthlyOccurrence() async throws {
        let plan = try #require(await execute(items: [item(id: 1, amount: 199)]))

        #expect(plan.plannedTotal.amount == 199)
        #expect(plan.chargeCount == 1)
    }

    @Test("Monthly occurrence outside the current month is excluded")
    func monthlyOutsideMonth() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 199,
                nextChargeDate: date(2026, 9, 20),
                billingCycle: .monthly,
                startDate: date(2026, 9, 1)
            )
        ]))

        #expect(plan.plannedTotal.amount == 0)
        #expect(plan.chargeCount == 0)
    }

    @Test("Weekly recurrence contributes every scheduled occurrence")
    func weeklyMultipleOccurrences() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 100,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1)
            )
        ]))

        #expect(plan.plannedTotal.amount == 500)
        #expect(plan.chargeCount == 5)
        #expect(plan.remainingTotal.amount == 300)
        #expect(plan.remainingChargeCount == 3)
    }

    @Test("An occurrence exactly on the next-month boundary is excluded")
    func nextMonthBoundaryExcluded() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 100,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .custom(days: 31),
                startDate: date(2026, 8, 1)
            )
        ]))

        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 100)
    }

    @Test("Quarterly, semiannual and annual charges due this month are included")
    func longCyclesDueThisMonth() async throws {
        let plan = try #require(await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: date(2026, 8, 5), billingCycle: .quarterly),
            item(id: 2, amount: 200, nextChargeDate: date(2026, 8, 10), billingCycle: .semiannual),
            item(id: 3, amount: 300, nextChargeDate: date(2026, 8, 20), billingCycle: .annual)
        ]))

        #expect(plan.chargeCount == 3)
        #expect(plan.plannedTotal.amount == 600)
    }

    @Test("Long-cycle charges not due this month are not prorated")
    func longCyclesNotDueThisMonth() async throws {
        let plan = try #require(await execute(items: [
            item(id: 1, nextChargeDate: date(2026, 9, 5), billingCycle: .quarterly),
            item(id: 2, nextChargeDate: date(2026, 10, 10), billingCycle: .semiannual),
            item(id: 3, nextChargeDate: date(2026, 11, 20), billingCycle: .annual)
        ]))

        #expect(plan.chargeCount == 0)
        #expect(plan.plannedTotal.amount == 0)
    }

    @Test("A positive custom cycle projects actual calendar occurrences")
    func validCustomCycle() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 25,
                nextChargeDate: date(2026, 8, 2),
                billingCycle: .custom(days: 10),
                startDate: date(2026, 1, 1)
            )
        ]))

        #expect(plan.chargeCount == 3)
        #expect(plan.plannedTotal.amount == 75)
    }

    @Test("Invalid custom cycles make a complete plan unavailable")
    func invalidCustomCycle() async throws {
        #expect(try await execute(items: [
            item(id: 1, billingCycle: .custom(days: 0))
        ]) == nil)
        #expect(try await execute(items: [
            item(id: 1, billingCycle: .custom(days: -7))
        ]) == nil)
    }

    @Test("A stale stored charge date rolls through every current-month occurrence")
    func staleDateRollover() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 10,
                nextChargeDate: date(2026, 7, 25),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1)
            )
        ]))

        #expect(plan.chargeCount == 5)
        #expect(plan.plannedTotal.amount == 50)
    }

    // MARK: - Lifecycle and Start Date

    @Test("Only lifecycle states that count in totals are eligible")
    func excludedLifecycleStates() async throws {
        for status in [ItemStatus.paused, .cancelled, .archived] {
            let plan = try #require(await execute(items: [item(id: 1, status: status)]))
            #expect(plan.chargeCount == 0)
            #expect(plan.plannedTotal.amount == 0)
        }

        let archivedPlan = try #require(await execute(items: [
            item(id: 1, status: .active, archivedAt: date(2026, 8, 1))
        ]))
        #expect(archivedPlan.chargeCount == 0)
    }

    @Test("Active lifecycle state is included")
    func activeStateIncluded() async throws {
        let plan = try #require(await execute(items: [item(id: 1, amount: 100)]))
        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 100)
    }

    @Test("An expired finite subscription is excluded from the whole plan")
    func expiredFiniteExcluded() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                nextChargeDate: date(2026, 8, 5),
                autoRenew: false,
                endDate: date(2026, 8, 12)
            )
        ]))

        #expect(plan.chargeCount == 0)
        #expect(plan.plannedTotal.amount == 0)
    }

    @Test("A finite subscription ending mid-month stops after its end day")
    func finiteEndingMidMonth() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 100,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1),
                autoRenew: false,
                endDate: date(2026, 8, 20)
            )
        ]))

        #expect(plan.chargeCount == 3)
        #expect(plan.plannedTotal.amount == 300)
        #expect(plan.remainingChargeCount == 1)
        #expect(plan.remainingTotal.amount == 100)
    }

    @Test("Malformed finite lifecycle boundaries make the plan unavailable")
    func malformedFiniteLifecycleUnavailable() async throws {
        let plan = try await execute(items: [
            item(
                id: 1,
                nextChargeDate: date(2026, 8, 20),
                autoRenew: false,
                endDate: date(2026, 8, 19)
            )
        ])

        #expect(plan == nil)
    }

    @Test("No occurrence is created before the subscription start day")
    func startDateBoundary() async throws {
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 10,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .weekly,
                startDate: date(2026, 8, 10)
            )
        ]))

        #expect(plan.chargeCount == 3)
        #expect(plan.plannedTotal.amount == 30)
    }

    @Test("Duplicate repository rows with the same identity are counted once")
    func duplicateIdentityCountedOnce() async throws {
        let original = item(id: 1, amount: 100)
        var newer = original
        newer.amount = 500
        newer.updatedAt = date(2026, 8, 12)

        let plan = try #require(await execute(items: [original, newer]))

        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 500)
    }

    // MARK: - Trial Truthfulness

    @Test("An ambiguous trial never produces a fabricated charge")
    func ambiguousTrialUnavailable() async throws {
        let plan = try await execute(items: [
            item(
                id: 1,
                amount: 169,
                nextChargeDate: date(2026, 8, 25),
                status: .trial,
                trialEndDate: date(2026, 8, 20)
            )
        ])

        #expect(plan == nil)
    }

    @Test("A trial with proven paid renewal terms contributes from the trial end day")
    func provenTrialRenewalIncluded() async throws {
        let trialEnd = date(2026, 8, 20, hour: 9)
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: 169,
                nextChargeDate: date(2026, 8, 20, hour: 18),
                status: .trial,
                trialEndDate: trialEnd
            )
        ]))

        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 169)
        #expect(plan.remainingChargeCount == 1)
    }

    // MARK: - Remaining Plan

    @Test("Remaining uses calendar-day semantics and includes today")
    func remainingIncludesToday() async throws {
        let plan = try #require(await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: date(2026, 8, 12), billingCycle: .annual),
            item(id: 2, amount: 200, nextChargeDate: date(2026, 8, 13, hour: 1), billingCycle: .annual),
            item(id: 3, amount: 300, nextChargeDate: date(2026, 8, 14), billingCycle: .annual)
        ]))

        #expect(plan.plannedTotal.amount == 600)
        #expect(plan.chargeCount == 3)
        #expect(plan.remainingTotal.amount == 500)
        #expect(plan.remainingChargeCount == 2)
    }

    // MARK: - Currency and Invalid Data

    @Test("Same-currency occurrences aggregate without FX")
    func sameCurrencyAggregation() async throws {
        let plan = try #require(await execute(items: [
            item(id: 1, amount: 199),
            item(id: 2, amount: 299)
        ]))

        #expect(plan.plannedTotal == (try Money(amount: 498, currencyCode: "RUB")))
    }

    @Test("Occurrence multiplication preserves Decimal precision")
    func decimalPrecision() async throws {
        let amount = try #require(Decimal(string: "12.34"))
        let expected = try #require(Decimal(string: "61.70"))
        let plan = try #require(await execute(items: [
            item(
                id: 1,
                amount: amount,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1)
            )
        ]))

        #expect(plan.plannedTotal.amount == expected)
        #expect(plan.plannedTotal.currencyCode == "RUB")
    }

    @Test("Complete mixed-currency FX produces one reporting-currency plan")
    func completeMixedCurrencyFX() async throws {
        let plan = try #require(await execute(
            items: [
                item(id: 1, amount: 10, currencyCode: "USD"),
                item(id: 2, amount: 500, currencyCode: "RUB")
            ],
            exchangeRateSnapshot: snapshot(rates: ["RUB": 90])
        ))

        #expect(plan.plannedTotal.amount == 1_400)
        #expect(plan.plannedTotal.currencyCode == "RUB")
    }

    @Test("Missing FX makes the complete plan unavailable")
    func missingFXUnavailable() async throws {
        let plan = try await execute(items: [
            item(id: 1, amount: 10, currencyCode: "USD"),
            item(id: 2, amount: 500, currencyCode: "RUB")
        ])

        #expect(plan == nil)
    }

    @Test("Malformed money never becomes a partial or zero contribution")
    func malformedMoneyUnavailable() async throws {
        #expect(try await execute(items: [item(id: 1, amount: 0)]) == nil)
        #expect(try await execute(items: [item(id: 1, amount: -1)]) == nil)
        #expect(try await execute(items: [item(id: 1, currencyCode: "???")]) == nil)
    }

    @Test("No subscriptions is a complete zero plan")
    func zeroSubscriptions() async throws {
        let plan = try #require(await execute(items: []))

        #expect(plan.plannedTotal == (try Money(amount: 0, currencyCode: "RUB")))
        #expect(plan.chargeCount == 0)
        #expect(plan.remainingTotal == (try Money(amount: 0, currencyCode: "RUB")))
        #expect(plan.remainingChargeCount == 0)
    }

    // MARK: - Calendar Determinism

    @Test("Explicit timezone determines the current calendar month")
    func explicitTimezone() async throws {
        let tokyo = fixedCalendar(timeZoneID: "Asia/Tokyo")
        let localToday = date(2026, 9, 1, hour: 1, calendar: tokyo)
        let plan = try #require(await execute(
            items: [item(
                id: 1,
                amount: 100,
                nextChargeDate: date(2026, 9, 1, hour: 23, calendar: tokyo),
                billingCycle: .annual,
                calendar: tokyo
            )],
            today: localToday,
            calendar: tokyo
        ))

        #expect(plan.chargeCount == 1)
        #expect(plan.remainingChargeCount == 1)
    }

    @Test("Calendar stepping remains day-based across DST")
    func dstSensitiveProjection() async throws {
        let losAngeles = fixedCalendar(timeZoneID: "America/Los_Angeles")
        let localToday = date(2026, 3, 9, hour: 10, calendar: losAngeles)
        let plan = try #require(await execute(
            items: [item(
                id: 1,
                amount: 10,
                nextChargeDate: date(2026, 3, 1, hour: 12, calendar: losAngeles),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1, calendar: losAngeles),
                calendar: losAngeles
            )],
            today: localToday,
            calendar: losAngeles
        ))

        #expect(plan.chargeCount == 5)
        #expect(plan.remainingChargeCount == 3)
        #expect(plan.plannedTotal.amount == 50)
    }
}

// MARK: - Test Support

private extension CurrentMonthSubscriptionPlanUseCaseTests {
    func execute(
        items: [RecurringItem],
        today: Date? = nil,
        calendar: Calendar? = nil,
        reportingCurrencyCode: String = "RUB",
        exchangeRateSnapshot: ExchangeRateSnapshot? = nil
    ) async throws -> MonthlySubscriptionPlan? {
        let repository = await CurrentMonthPlanRepositoryStub(items: items)
        let useCase = CurrentMonthSubscriptionPlanUseCase(repository: repository)
        return try await useCase.execute(
            today: today ?? self.today,
            calendar: calendar ?? self.calendar,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot
        )
    }

    func item(
        id index: Int,
        amount: Decimal = 100,
        currencyCode: String = "RUB",
        nextChargeDate: Date? = nil,
        billingCycle: BillingCycle = .monthly,
        startDate: Date? = nil,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        status: ItemStatus = .active,
        trialEndDate: Date? = nil,
        archivedAt: Date? = nil,
        calendar: Calendar? = nil
    ) -> RecurringItem {
        let selectedCalendar = calendar ?? self.calendar
        let created = date(2025, 1, 1, calendar: selectedCalendar)
        return RecurringItem(
            id: id(index),
            title: "Item \(index)",
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            startDate: startDate ?? created,
            nextChargeDate: nextChargeDate ?? date(2026, 8, 20, calendar: selectedCalendar),
            trialEndDate: trialEndDate,
            autoRenew: autoRenew,
            endDate: endDate,
            status: status,
            createdAt: created,
            updatedAt: created,
            archivedAt: archivedAt
        )
    }

    func fixedCalendar(timeZoneID: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .gmt
        return calendar
    }

    func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        calendar: Calendar? = nil
    ) -> Date {
        let selectedCalendar = calendar ?? self.calendar
        var components = DateComponents()
        components.calendar = selectedCalendar
        components.timeZone = selectedCalendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return selectedCalendar.date(from: components) ?? .distantPast
    }

    func id(_ value: Int) -> UUID {
        UUID(uuid: (
            0, 0, 0, 0,
            0, 0,
            0, 0,
            0, 0,
            0, 0, 0, 0,
            UInt8(truncatingIfNeeded: value >> 8),
            UInt8(truncatingIfNeeded: value)
        ))
    }

    func snapshot(rates: [String: Decimal]) -> ExchangeRateSnapshot {
        ExchangeRateSnapshot(
            exchangeRates: ExchangeRates(
                base: "USD",
                date: date(2026, 8, 12),
                rates: rates,
                fetchedAt: date(2026, 8, 12)
            ),
            freshness: .fresh
        )
    }
}

private enum CurrentMonthPlanRepositoryStubError: Error {
    case unsupportedWrite
}

@MainActor
private final class CurrentMonthPlanRepositoryStub: RecurringItemRepository {
    private let items: [RecurringItem]

    init(items: [RecurringItem]) {
        self.items = items
    }

    func fetchAll() throws -> [RecurringItem] {
        items
    }

    func fetchActive() throws -> [RecurringItem] {
        items.filter { $0.status.countsInTotals }
    }

    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] {
        let end = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return items.filter { $0.nextChargeDate >= date && $0.nextChargeDate <= end }
    }

    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] {
        items.filter { $0.category == category }
    }

    func fetch(id: UUID) throws -> RecurringItem? {
        items.first { $0.id == id }
    }

    func save(_ item: RecurringItem) throws {
        throw CurrentMonthPlanRepositoryStubError.unsupportedWrite
    }

    func update(_ item: RecurringItem) throws {
        throw CurrentMonthPlanRepositoryStubError.unsupportedWrite
    }

    func delete(id: UUID) throws {
        throw CurrentMonthPlanRepositoryStubError.unsupportedWrite
    }

    func saveAll(_ items: [RecurringItem]) throws {
        throw CurrentMonthPlanRepositoryStubError.unsupportedWrite
    }

    func deleteAll() throws {
        throw CurrentMonthPlanRepositoryStubError.unsupportedWrite
    }
}
