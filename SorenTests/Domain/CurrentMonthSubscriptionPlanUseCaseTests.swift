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

    @Test("Monthly projection recovers the original day after February clamp")
    func monthlyAnchorRecovery() async throws {
        let localToday = date(2026, 3, 29)
        let plan = try #require(await execute(
            items: [item(
                id: 1,
                amount: 100,
                nextChargeDate: date(2026, 1, 31),
                billingCycle: .monthly,
                startDate: date(2026, 1, 1)
            )],
            today: localToday
        ))

        #expect(plan.chargeCount == 1)
        #expect(plan.plannedTotal.amount == 100)
        #expect(plan.remainingChargeCount == 1)
        #expect(plan.remainingTotal.amount == 100)
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

    @Test("Finite subscription without an end date makes the plan unavailable")
    func finiteWithoutEndDateUnavailable() async throws {
        let plan = try await execute(items: [
            item(
                id: 1,
                nextChargeDate: date(2026, 8, 20),
                autoRenew: false
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

    // MARK: - Snapshot Contract

    @Test("Snapshot plan matches the compatible plan API with one fetch per execution")
    func snapshotPlanParity() async throws {
        let items = [
            item(id: 1, amount: 100),
            item(id: 2, amount: 200, nextChargeDate: date(2026, 8, 25)),
        ]
        let snapshotRepository = await CurrentMonthPlanRepositoryStub(items: items)
        let snapshotUseCase = CurrentMonthSubscriptionPlanUseCase(repository: snapshotRepository)
        let snapshot = try #require(await snapshotUseCase.executeSnapshot(
            today: today,
            calendar: calendar,
            reportingCurrencyCode: "RUB",
            exchangeRateSnapshot: nil
        ))

        let planRepository = await CurrentMonthPlanRepositoryStub(items: items)
        let planUseCase = CurrentMonthSubscriptionPlanUseCase(repository: planRepository)
        let plan = try #require(await planUseCase.execute(
            today: today,
            calendar: calendar,
            reportingCurrencyCode: "RUB",
            exchangeRateSnapshot: nil
        ))

        #expect(snapshot.plan == plan)
        #expect(snapshot.scheduledCharges.count == snapshot.plan.chargeCount)
        #expect(await snapshotRepository.fetchAllCallCount == 1)
        #expect(await planRepository.fetchAllCallCount == 1)
    }

    @Test("Every canonical weekly occurrence crosses the snapshot boundary")
    func snapshotPreservesRepeatedOccurrenceDates() async throws {
        let snapshot = try #require(await executeSnapshot(items: [
            item(
                id: 1,
                amount: 10,
                nextChargeDate: date(2026, 8, 1),
                billingCycle: .weekly,
                startDate: date(2026, 1, 1)
            )
        ]))
        let expectedDates = [1, 8, 15, 22, 29].map {
            date(2026, 8, $0, hour: 0)
        }

        #expect(snapshot.scheduledCharges.map(\.date) == expectedDates)
        #expect(snapshot.scheduledCharges.map(\.itemID) == Array(repeating: id(1), count: 5))
        #expect(snapshot.scheduledCharges.count == snapshot.plan.chargeCount)
    }

    @Test("Occurrences are ordered by date then UUID without merging a shared day")
    func snapshotOccurrenceOrderingAndSameDayMultiplicity() async throws {
        let snapshot = try #require(await executeSnapshot(items: [
            item(id: 3, nextChargeDate: date(2026, 8, 20), billingCycle: .annual),
            item(id: 1, nextChargeDate: date(2026, 8, 20), billingCycle: .annual),
            item(id: 2, nextChargeDate: date(2026, 8, 10), billingCycle: .annual),
        ]))

        #expect(snapshot.scheduledCharges == [
            ScheduledChargeOccurrence(itemID: id(2), date: date(2026, 8, 10, hour: 0)),
            ScheduledChargeOccurrence(itemID: id(1), date: date(2026, 8, 20, hour: 0)),
            ScheduledChargeOccurrence(itemID: id(3), date: date(2026, 8, 20, hour: 0)),
        ])
    }

    @Test("A trial boundary does not add a second monetary occurrence")
    func snapshotExcludesTrialBoundary() async throws {
        let renewalDay = date(2026, 8, 20)
        let snapshot = try #require(await executeSnapshot(items: [
            item(
                id: 1,
                amount: 169,
                nextChargeDate: renewalDay,
                status: .trial,
                trialEndDate: renewalDay
            )
        ]))

        #expect(snapshot.scheduledCharges == [
            ScheduledChargeOccurrence(itemID: id(1), date: date(2026, 8, 20, hour: 0))
        ])
        #expect(snapshot.plan.chargeCount == 1)
    }

    @Test(
        "Every approved current active status contributes to the active count",
        arguments: [
            ItemStatus.active,
            .dueSoon,
            .dueToday,
            .overdue,
            .failed,
        ]
    )
    func snapshotCountsCurrentActiveStatuses(_ status: ItemStatus) async throws {
        let snapshot = try #require(await executeSnapshot(items: [
            item(id: 1, status: status)
        ]))

        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 1, trial: 0, paused: 0))
    }

    @Test("Finite end dates are inclusive by supplied calendar day")
    func snapshotCurrentEndDateSemantics() async throws {
        let snapshot = try #require(await executeSnapshot(items: [
            item(
                id: 1,
                nextChargeDate: date(2026, 8, 13, hour: 1),
                autoRenew: false,
                endDate: date(2026, 8, 13, hour: 23)
            ),
            item(
                id: 2,
                nextChargeDate: date(2026, 8, 12),
                autoRenew: false,
                endDate: date(2026, 8, 12, hour: 23)
            ),
            item(
                id: 3,
                nextChargeDate: date(2026, 8, 14),
                autoRenew: false,
                endDate: date(2026, 8, 14)
            ),
        ]))

        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 2, trial: 0, paused: 0))
    }

    @Test("Archived items never enter any status bucket")
    func snapshotExcludesArchivedItemsFromEveryBucket() async throws {
        let archivedAt = date(2026, 8, 1)
        let snapshot = try #require(await executeSnapshot(items: [
            item(id: 1, status: .active, archivedAt: archivedAt),
            item(id: 2, status: .trial, archivedAt: archivedAt),
            item(id: 3, status: .paused, archivedAt: archivedAt),
        ]))

        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 0, trial: 0, paused: 0))
    }

    @Test("Current status buckets are mutually exclusive")
    func snapshotStatusBucketsDoNotDoubleCount() async throws {
        let renewalDay = date(2026, 8, 20)
        let snapshot = try #require(await executeSnapshot(items: [
            item(id: 1, status: .active),
            item(id: 2, status: .overdue),
            item(id: 3, status: .failed),
            item(id: 4, nextChargeDate: renewalDay, status: .trial, trialEndDate: renewalDay),
            item(id: 5, status: .paused),
            item(id: 6, status: .cancelled),
            item(id: 7, status: .archived),
        ]))

        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 3, trial: 1, paused: 1))
        #expect(
            snapshot.statusCounts.active
                + snapshot.statusCounts.trial
                + snapshot.statusCounts.paused == 5
        )
    }

    @Test("Empty input produces an empty plan snapshot")
    func emptySnapshot() async throws {
        let snapshot = try #require(await executeSnapshot(items: []))

        #expect(snapshot.plan.plannedTotal == (try Money(amount: 0, currencyCode: "RUB")))
        #expect(snapshot.plan.chargeCount == 0)
        #expect(snapshot.scheduledCharges.isEmpty)
        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 0, trial: 0, paused: 0))
    }

    @Test("Status expiry uses the supplied calendar rather than the host timezone")
    func snapshotStatusCountsUseSuppliedCalendar() async throws {
        let tokyo = fixedCalendar(timeZoneID: "Asia/Tokyo")
        let localToday = date(2026, 9, 1, hour: 1, calendar: tokyo)
        let snapshot = try #require(await executeSnapshot(
            items: [
                item(
                    id: 1,
                    nextChargeDate: date(2026, 9, 1, calendar: tokyo),
                    autoRenew: false,
                    endDate: date(2026, 9, 1, hour: 23, calendar: tokyo),
                    status: .paused,
                    calendar: tokyo
                ),
                item(
                    id: 2,
                    nextChargeDate: date(2026, 8, 31, calendar: tokyo),
                    autoRenew: false,
                    endDate: date(2026, 8, 31, hour: 23, calendar: tokyo),
                    status: .paused,
                    calendar: tokyo
                ),
            ],
            today: localToday,
            calendar: tokyo
        ))

        #expect(snapshot.statusCounts == SubscriptionStatusCounts(active: 0, trial: 0, paused: 1))
    }

    @Test("Repository failures propagate from the snapshot API")
    func snapshotPropagatesRepositoryErrors() async {
        let repository = await CurrentMonthPlanRepositoryStub(
            items: [],
            fetchError: .fetchFailed
        )
        let useCase = CurrentMonthSubscriptionPlanUseCase(repository: repository)

        await #expect(throws: CurrentMonthPlanRepositoryStubError.fetchFailed) {
            try await useCase.executeSnapshot(
                today: today,
                calendar: calendar,
                reportingCurrencyCode: "RUB",
                exchangeRateSnapshot: nil
            )
        }
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

    func executeSnapshot(
        items: [RecurringItem],
        today: Date? = nil,
        calendar: Calendar? = nil,
        reportingCurrencyCode: String = "RUB",
        exchangeRateSnapshot: ExchangeRateSnapshot? = nil
    ) async throws -> CurrentMonthSubscriptionPlanSnapshot? {
        let repository = await CurrentMonthPlanRepositoryStub(items: items)
        let useCase = CurrentMonthSubscriptionPlanUseCase(repository: repository)
        return try await useCase.executeSnapshot(
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

private enum CurrentMonthPlanRepositoryStubError: Error, Equatable {
    case fetchFailed
    case unsupportedWrite
}

@MainActor
private final class CurrentMonthPlanRepositoryStub: RecurringItemRepository {
    private let items: [RecurringItem]
    private let fetchError: CurrentMonthPlanRepositoryStubError?
    private(set) var fetchAllCallCount = 0

    init(
        items: [RecurringItem],
        fetchError: CurrentMonthPlanRepositoryStubError? = nil
    ) {
        self.items = items
        self.fetchError = fetchError
    }

    func fetchAll() throws -> [RecurringItem] {
        fetchAllCallCount += 1
        if let fetchError { throw fetchError }
        return items
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
