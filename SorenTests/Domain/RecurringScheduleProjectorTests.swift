import Foundation
import Testing
@testable import Soren

@Suite("RecurringScheduleProjector")
struct RecurringScheduleProjectorTests {
    // MARK: - Interval

    @Test("Interval start is included and interval end is excluded")
    func halfOpenInterval() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let end = try date(2026, 9, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, billingCycle: .monthly),
            from: start,
            to: end,
            asOf: start,
            calendar: calendar
        )

        #expect(projection.monetaryCompleteness == .complete)
        #expect(chargeDates(in: projection) == [start])
    }

    @Test("An empty interval is a complete empty projection")
    func emptyInterval() throws {
        let calendar = try fixedCalendar()
        let boundary = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(anchor: boundary),
            from: boundary,
            to: boundary,
            asOf: boundary,
            calendar: calendar
        )

        #expect(projection == RecurringScheduleProjection(
            events: [],
            monetaryCompleteness: .complete
        ))
    }

    @Test("An interval without an occurrence is complete and empty")
    func noOccurrenceInRange() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let end = try date(2026, 8, 10, calendar: calendar)
        let anchor = try date(2026, 8, 20, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .annual),
            from: start,
            to: end,
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .complete)
    }

    // MARK: - Day-Based Recurrence

    @Test("Weekly recurrence returns every occurrence in the interval")
    func weeklyOccurrences() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let end = try date(2026, 9, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, billingCycle: .weekly),
            from: start,
            to: end,
            asOf: start,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 8, 1),
            (2026, 8, 8),
            (2026, 8, 15),
            (2026, 8, 22),
            (2026, 8, 29)
        ], calendar: calendar)))
    }

    @Test("Weekly recurrence preserves civil days across daylight-saving time")
    func weeklyAcrossDST() throws {
        let calendar = try fixedCalendar(timeZoneID: "America/Los_Angeles")
        let start = try date(2026, 3, 1, calendar: calendar)
        let end = try date(2026, 4, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, billingCycle: .weekly),
            from: start,
            to: end,
            asOf: start,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 3, 1),
            (2026, 3, 8),
            (2026, 3, 15),
            (2026, 3, 22),
            (2026, 3, 29)
        ], calendar: calendar)))
    }

    @Test("Custom day recurrence does not drift by fixed seconds across DST")
    func customDaysAcrossDST() throws {
        let calendar = try fixedCalendar(timeZoneID: "America/Los_Angeles")
        let start = try date(2026, 3, 6, calendar: calendar)
        let end = try date(2026, 3, 16, calendar: calendar)
        let projection = try project(
            item(anchor: start, billingCycle: .custom(days: 3)),
            from: start,
            to: end,
            asOf: start,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 3, 6),
            (2026, 3, 9),
            (2026, 3, 12),
            (2026, 3, 15)
        ], calendar: calendar)))
    }

    // MARK: - Monthly Family

    @Test("Monthly recurrence preserves a normal anchor day")
    func monthlyNormalDay() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 1, 15, calendar: calendar)
        let end = try date(2026, 5, 1, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .monthly),
            from: try date(2026, 1, 1, calendar: calendar),
            to: end,
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 1, 15),
            (2026, 2, 15),
            (2026, 3, 15),
            (2026, 4, 15)
        ], calendar: calendar)))
    }

    @Test(
        "Monthly clamp recovers the original anchor",
        arguments: [
            (30, [(2026, 1, 30), (2026, 2, 28), (2026, 3, 30), (2026, 4, 30), (2026, 5, 30)]),
            (31, [(2026, 1, 31), (2026, 2, 28), (2026, 3, 31), (2026, 4, 30), (2026, 5, 31)])
        ]
    )
    func monthlyAnchorRecovery(
        anchorDay: Int,
        expectedComponents: [(Int, Int, Int)]
    ) throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 1, anchorDay, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .monthly),
            from: try date(2026, 1, 1, calendar: calendar),
            to: try date(2026, 6, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )
        let projectedDates = chargeDates(in: projection)

        #expect(projectedDates == (try dates(expectedComponents, calendar: calendar)))
        #expect(Set(projectedDates).count == projectedDates.count)
    }

    @Test("A monthly end-of-month anchor follows each target month end")
    func monthlyEndOfMonth() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 4, 30, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .monthly),
            from: try date(2026, 4, 1, calendar: calendar),
            to: try date(2026, 8, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 4, 30),
            (2026, 5, 31),
            (2026, 6, 30),
            (2026, 7, 31)
        ], calendar: calendar)))
    }

    @Test("Quarterly clamp recovers the original anchor")
    func quarterlyAnchorRecovery() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2025, 11, 29, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .quarterly),
            from: try date(2025, 11, 1, calendar: calendar),
            to: try date(2026, 6, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2025, 11, 29),
            (2026, 2, 28),
            (2026, 5, 29)
        ], calendar: calendar)))
    }

    @Test("Semiannual clamp recovers the original anchor")
    func semiannualAnchorRecovery() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2025, 8, 30, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .semiannual),
            from: try date(2025, 8, 1, calendar: calendar),
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2025, 8, 30),
            (2026, 2, 28),
            (2026, 8, 30)
        ], calendar: calendar)))
    }

    // MARK: - Annual Recurrence

    @Test("Annual recurrence preserves a normal month and day")
    func annualNormalDate() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2024, 7, 15, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .annual),
            from: try date(2024, 1, 1, calendar: calendar),
            to: try date(2027, 1, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2024, 7, 15),
            (2025, 7, 15),
            (2026, 7, 15)
        ], calendar: calendar)))
    }

    @Test("February twenty-ninth annual anchor recovers in a leap year")
    func annualLeapDayRecovery() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2024, 2, 29, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .annual),
            from: try date(2024, 1, 1, calendar: calendar),
            to: try date(2029, 1, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2024, 2, 29),
            (2025, 2, 28),
            (2026, 2, 28),
            (2027, 2, 28),
            (2028, 2, 29)
        ], calendar: calendar)))
    }

    @Test("A past stored anchor projects into an arbitrary future interval")
    func pastAnchorFutureInterval() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2020, 5, 10, calendar: calendar)
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .monthly),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == [
            try date(2026, 8, 10, calendar: calendar)
        ])
    }

    @Test("A future stored anchor projects earlier members of the same cadence")
    func futureAnchorEarlierInterval() throws {
        let calendar = try fixedCalendar()
        let lifecycleStart = try date(2026, 1, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 3, 31, calendar: calendar),
                billingCycle: .monthly,
                startDate: lifecycleStart
            ),
            from: lifecycleStart,
            to: try date(2026, 3, 1, calendar: calendar),
            asOf: lifecycleStart,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 1, 31),
            (2026, 2, 28)
        ], calendar: calendar)))
    }

    // MARK: - Lifecycle

    @Test("Start date excludes earlier occurrences and includes its occurrence")
    func startDateBound() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let lifecycleStart = try date(2026, 8, 8, calendar: calendar)
        let projection = try project(
            item(
                anchor: intervalStart,
                billingCycle: .weekly,
                startDate: lifecycleStart
            ),
            from: intervalStart,
            to: try date(2026, 8, 16, calendar: calendar),
            asOf: intervalStart,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 8, 8),
            (2026, 8, 15)
        ], calendar: calendar)))
    }

    @Test("End date includes its occurrence and excludes later occurrences")
    func endDateBound() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 8, 1, calendar: calendar)
        let endDate = try date(2026, 8, 15, calendar: calendar)
        let projection = try project(
            item(
                anchor: anchor,
                billingCycle: .weekly,
                autoRenew: false,
                endDate: endDate
            ),
            from: anchor,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 8, 1),
            (2026, 8, 8),
            (2026, 8, 15)
        ], calendar: calendar)))
    }

    @Test("Expired finite item is excluded relative to the explicit reference day")
    func expiredFiniteItem() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 5, calendar: calendar),
                autoRenew: false,
                endDate: try date(2026, 8, 12, calendar: calendar)
            ),
            from: intervalStart,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: try date(2026, 8, 13, calendar: calendar),
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .complete)
    }

    @Test("Malformed finite bounds make monetary projection unavailable")
    func malformedFiniteBounds() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                startDate: intervalStart,
                autoRenew: false,
                endDate: try date(2026, 8, 19, calendar: calendar)
            ),
            from: intervalStart,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: intervalStart,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Start date after end date makes monetary projection unavailable")
    func malformedLifecycleOrder() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 10, calendar: calendar),
                startDate: try date(2026, 8, 20, calendar: calendar),
                autoRenew: false,
                endDate: try date(2026, 8, 19, calendar: calendar)
            ),
            from: intervalStart,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: intervalStart,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Existing end date remains a hard bound for legacy auto-renew data")
    func autoRenewWithEndDate() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: anchor,
                billingCycle: .weekly,
                autoRenew: true,
                endDate: try date(2026, 8, 15, calendar: calendar)
            ),
            from: anchor,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == (try dates([
            (2026, 8, 1),
            (2026, 8, 8),
            (2026, 8, 15)
        ], calendar: calendar)))
    }

    @Test("Malformed monetary schedule retains an independently known trial boundary")
    func malformedScheduleRetainsTrialBoundary() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let trialEnd = try date(2026, 8, 15, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                startDate: intervalStart,
                autoRenew: false,
                endDate: try date(2026, 8, 19, calendar: calendar),
                status: .trial,
                trialEndDate: trialEnd
            ),
            from: intervalStart,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: intervalStart,
            calendar: calendar
        )

        #expect(projection.events == [
            .trialEnd(itemID: id(1), date: trialEnd)
        ])
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Finite item without an end date has unavailable monetary truth")
    func finiteItemWithoutEndDate() throws {
        let calendar = try fixedCalendar()
        let intervalStart = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                autoRenew: false
            ),
            from: intervalStart,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: intervalStart,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test(
        "Monetary lifecycle statuses are included",
        arguments: [
            ItemStatus.active,
            .dueSoon,
            .dueToday,
            .overdue,
            .failed
        ]
    )
    func includedStatus(_ status: ItemStatus) throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let anchor = try date(2026, 8, 20, calendar: calendar)
        let projection = try project(
            item(anchor: anchor, billingCycle: .annual, status: status),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(chargeDates(in: projection) == [anchor])
        #expect(projection.monetaryCompleteness == .complete)
    }

    @Test(
        "Non-scheduling lifecycle statuses are excluded",
        arguments: [
            ItemStatus.paused,
            .cancelled,
            .archived
        ]
    )
    func excludedStatus(_ status: ItemStatus) throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                billingCycle: .annual,
                status: status
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .complete)
    }

    @Test("Archived timestamp excludes an otherwise active item")
    func archivedTimestamp() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                archivedAt: start
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .complete)
    }

    // MARK: - Trial Truth

    @Test("Ambiguous trial exposes a non-monetary boundary without a charge")
    func ambiguousTrialBoundary() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let trialEnd = try date(2026, 8, 20, hour: 9, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 25, calendar: calendar),
                startDate: start,
                status: .trial,
                trialEndDate: trialEnd
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )
        let boundaryDay = calendar.startOfDay(for: trialEnd)

        #expect(projection.events == [
            .trialEnd(itemID: id(1), date: boundaryDay)
        ])
        #expect(projection.monetaryCompleteness == .unavailable)
        #expect(chargeDates(in: projection).isEmpty)
    }

    @Test("Proven trial renewal emits boundary and charge as distinct events")
    func provenTrialRenewal() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let trialEnd = try date(2026, 8, 20, hour: 9, calendar: calendar)
        let nextCharge = try date(2026, 8, 20, hour: 18, calendar: calendar)
        let projection = try project(
            item(
                anchor: nextCharge,
                startDate: start,
                status: .trial,
                trialEndDate: trialEnd
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )
        let eventDay = calendar.startOfDay(for: trialEnd)

        #expect(projection.events == [
            .trialEnd(itemID: id(1), date: eventDay),
            .scheduledCharge(
                itemID: id(1),
                date: eventDay,
                money: try Money(amount: 100, currencyCode: "RUB")
            )
        ])
        #expect(projection.monetaryCompleteness == .complete)
    }

    @Test("Trial without auto-renewal does not prove a paid renewal")
    func trialWithoutAutoRenewal() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let trialEnd = try date(2026, 8, 20, hour: 9, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, hour: 18, calendar: calendar),
                startDate: start,
                autoRenew: false,
                endDate: try date(2026, 8, 31, calendar: calendar),
                status: .trial,
                trialEndDate: trialEnd
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events == [
            .trialEnd(itemID: id(1), date: calendar.startOfDay(for: trialEnd))
        ])
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Charge earlier than trial end on the same day is not a proven renewal")
    func chargeEarlierThanTrialEnd() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let trialEnd = try date(2026, 8, 20, hour: 9, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, hour: 8, calendar: calendar),
                startDate: start,
                status: .trial,
                trialEndDate: trialEnd
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events == [
            .trialEnd(itemID: id(1), date: calendar.startOfDay(for: trialEnd))
        ])
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Trial without a known boundary never fabricates a charge")
    func trialWithoutBoundary() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(
                anchor: try date(2026, 8, 20, calendar: calendar),
                startDate: start,
                status: .trial
            ),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    // MARK: - Integrity

    @Test("Projection does not mutate the persisted schedule anchor")
    func persistedAnchorIsNotMutated() throws {
        let calendar = try fixedCalendar()
        let anchor = try date(2026, 1, 31, hour: 18, calendar: calendar)
        let source = item(anchor: anchor, billingCycle: .monthly)

        _ = try project(
            source,
            from: try date(2026, 1, 1, calendar: calendar),
            to: try date(2026, 5, 1, calendar: calendar),
            asOf: anchor,
            calendar: calendar
        )

        #expect(source.nextChargeDate == anchor)
    }

    @Test("Non-positive amounts make monetary projection unavailable", arguments: [Decimal(0), Decimal(-1)])
    func invalidAmount(_ amount: Decimal) throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, amount: amount),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Malformed currency makes monetary projection unavailable")
    func malformedCurrency() throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, currencyCode: "???"),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }

    @Test("Non-positive custom interval makes monetary projection unavailable", arguments: [0, -7])
    func invalidCustomInterval(_ days: Int) throws {
        let calendar = try fixedCalendar()
        let start = try date(2026, 8, 1, calendar: calendar)
        let projection = try project(
            item(anchor: start, billingCycle: .custom(days: days)),
            from: start,
            to: try date(2026, 9, 1, calendar: calendar),
            asOf: start,
            calendar: calendar
        )

        #expect(projection.events.isEmpty)
        #expect(projection.monetaryCompleteness == .unavailable)
    }
}

// MARK: - Test Support

private extension RecurringScheduleProjectorTests {
    func project(
        _ item: RecurringItem,
        from start: Date,
        to end: Date,
        asOf referenceDate: Date,
        calendar: Calendar
    ) throws -> RecurringScheduleProjection {
        try RecurringScheduleProjector().project(
            item,
            in: start..<end,
            asOf: referenceDate,
            calendar: calendar
        )
    }

    func item(
        anchor: Date,
        amount: Decimal = 100,
        currencyCode: String = "RUB",
        billingCycle: BillingCycle = .monthly,
        startDate: Date? = nil,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        status: ItemStatus = .active,
        trialEndDate: Date? = nil,
        archivedAt: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            id: id(1),
            title: "Schedule",
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            startDate: startDate ?? anchor,
            nextChargeDate: anchor,
            trialEndDate: trialEndDate,
            autoRenew: autoRenew,
            endDate: endDate,
            status: status,
            createdAt: startDate ?? anchor,
            updatedAt: startDate ?? anchor,
            archivedAt: archivedAt
        )
    }

    func chargeDates(in projection: RecurringScheduleProjection) -> [Date] {
        projection.events.compactMap { event in
            guard case let .scheduledCharge(_, date, _) = event else {
                return nil
            }
            return date
        }
    }

    func fixedCalendar(timeZoneID: String = "UTC") throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        return calendar
    }

    func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar
    ) throws -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return try #require(calendar.date(from: components))
    }

    func dates(
        _ values: [(Int, Int, Int)],
        calendar: Calendar
    ) throws -> [Date] {
        try values.map {
            try date($0.0, $0.1, $0.2, calendar: calendar)
        }
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
}
