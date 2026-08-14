import Foundation
import Testing
@testable import Soren

@Suite("OverviewInsightUseCase")
struct OverviewInsightUseCaseTests {
    private var calendar: Calendar {
        fixedCalendar(timeZoneID: "UTC")
    }

    private var today: Date {
        Date(timeIntervalSince1970: 1_767_225_600 + 10 * 60 * 60)
    }

    // MARK: - Trial Attention

    @Test("Trial ending later today qualifies")
    func trialEndsToday() async throws {
        let trialEnd = day(0, hour: 18)
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: trialEnd)
        ])

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial-ending attention")
            return
        }
        #expect(details.itemID == id(1))
        #expect(details.trialEndDate == trialEnd)
    }

    @Test("Trial ending in exactly three calendar days qualifies")
    func trialEndsInExactlyThreeDays() async throws {
        let trialEnd = day(3)
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: trialEnd)
        ])

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial-ending attention")
            return
        }
        #expect(details.trialEndDate == trialEnd)
    }

    @Test("Trial ending on day four does not qualify")
    func trialEndingOnDayFourDoesNotQualify() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: day(4))
        ])

        #expect(insight == nil)
    }

    @Test("Already expired trial does not qualify")
    func expiredTrialDoesNotQualify() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: day(0, hour: 8))
        ])

        #expect(insight == nil)
    }

    @Test("Non-trial item does not qualify from trialEndDate alone")
    func nonTrialWithEndDateDoesNotQualify() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .active, trialEndDate: day(2))
        ])

        guard case .annualScale? = insight else {
            Issue.record("Expected annual fallback, not trial attention")
            return
        }
    }

    @Test("Trial without an end date does not qualify")
    func trialWithNilEndDateDoesNotQualify() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: nil)
        ])

        #expect(insight == nil)
    }

    @Test("Earliest trial wins")
    func multipleTrialsChooseEarliest() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: day(3)),
            item(id: 2, status: .trial, trialEndDate: day(1))
        ])

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial-ending attention")
            return
        }
        #expect(details.itemID == id(2))
    }

    @Test("Equal trial dates use stable UUID ordering")
    func equalTrialDatesUseUUIDTieBreak() async throws {
        let commonEnd = day(2)
        let insight = try await execute(items: [
            item(id: 9, status: .trial, trialEndDate: commonEnd),
            item(id: 2, status: .trial, trialEndDate: commonEnd)
        ])

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial-ending attention")
            return
        }
        #expect(details.itemID == id(2))
    }

    @Test("Ambiguous trial data never fabricates renewal terms")
    func ambiguousTrialTermsAreNotFabricated() async throws {
        let insight = try await execute(items: [
            item(
                id: 1,
                amount: 169,
                billingCycle: .monthly,
                nextChargeDate: day(10),
                status: .trial,
                trialEndDate: day(2)
            )
        ])

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial-ending attention")
            return
        }
        #expect(details.renewalTerms == nil)
    }

    // MARK: - Same-Day Attention

    @Test("Exactly three same-day renewals qualify")
    func exactlyThreeSameDayRenewalsQualify() async throws {
        let insight = try await execute(items: sameDayItems(count: 3, dayOffset: 2))

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.chargeCount == 3)
        #expect(details.chargeDate == calendar.startOfDay(for: day(2)))
    }

    @Test("Two same-day renewals do not qualify")
    func twoSameDayRenewalsDoNotQualify() async throws {
        let insight = try await execute(items: sameDayItems(count: 2, dayOffset: 2))

        #expect(!isSameDayAttention(insight))
    }

    @Test("Four same-day renewals qualify")
    func fourSameDayRenewalsQualify() async throws {
        let insight = try await execute(items: sameDayItems(count: 4, dayOffset: 2))

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.chargeCount == 4)
    }

    @Test("Same-day cluster at day seven is outside the attention horizon")
    func sameDayClusterOutsideSevenDayHorizon() async throws {
        let insight = try await execute(items: sameDayItems(count: 3, dayOffset: 7))

        #expect(!isSameDayAttention(insight))
        guard case .denseWeek? = insight else {
            Issue.record("Expected the truthful lower-priority dense-week insight")
            return
        }
    }

    @Test("Paused, cancelled, archived, and expired finite items are excluded from same-day count")
    func sameDayLifecycleExclusions() async throws {
        let excluded: [RecurringItem] = [
            item(id: 3, nextChargeDate: day(2), status: .paused),
            item(id: 4, nextChargeDate: day(2), status: .cancelled),
            item(id: 5, nextChargeDate: day(2), status: .archived),
            item(id: 6, nextChargeDate: day(2), archivedAt: day(-1)),
            item(
                id: 7,
                nextChargeDate: day(-2),
                autoRenew: false,
                endDate: day(-1),
                status: .active
            )
        ]

        for excludedItem in excluded {
            let insight = try await execute(items: [
                item(id: 1, nextChargeDate: day(2)),
                item(id: 2, nextChargeDate: day(2)),
                excludedItem
            ])
            #expect(!isSameDayAttention(insight))
        }
    }

    @Test("One recurring subscription contributes only its nearest event")
    func oneSubscriptionIsCountedOnce() async throws {
        let insight = try await execute(items: [
            item(id: 1, billingCycle: .weekly, nextChargeDate: day(1))
        ])

        #expect(!isSameDayAttention(insight))
        #expect(!isDenseWeek(insight))
    }

    @Test("Same-day output IDs are deterministic")
    func sameDayOrderingIsDeterministic() async throws {
        let insight = try await execute(items: [
            item(id: 9, nextChargeDate: day(2)),
            item(id: 2, nextChargeDate: day(2)),
            item(id: 5, nextChargeDate: day(2))
        ])

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.itemIDs == [id(2), id(5), id(9)])
    }

    @Test("Complete mixed-currency same-day total is converted")
    func sameDayCompleteFXTotal() async throws {
        let insight = try await execute(
            items: [
                item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(2)),
                item(id: 2, amount: 100, nextChargeDate: day(2)),
                item(id: 3, amount: 200, nextChargeDate: day(2))
            ],
            exchangeRateSnapshot: snapshot(rates: ["RUB": 100])
        )

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.total?.amount == 400)
        #expect(details.total?.currencyCode == "RUB")
    }

    @Test("Unavailable FX removes only the same-day total")
    func sameDayUnavailableFXReturnsNilTotal() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(2)),
            item(id: 2, amount: 100, nextChargeDate: day(2)),
            item(id: 3, amount: 200, nextChargeDate: day(2))
        ])

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.total == nil)
        #expect(details.chargeCount == 3)
    }

    // MARK: - Dense Week

    @Test("Exactly three renewals in a rolling seven-day window qualify")
    func exactlyThreeDenseWeekQualify() async throws {
        let insight = try await execute(items: items(onDays: [0, 3, 6]))

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week")
            return
        }
        #expect(details.chargeCount == 3)
        #expect(details.firstChargeDate == calendar.startOfDay(for: day(0)))
        #expect(details.lastChargeDate == calendar.startOfDay(for: day(6)))
    }

    @Test("Only two renewals do not produce dense week")
    func onlyTwoDoNotProduceDenseWeek() async throws {
        let insight = try await execute(items: items(onDays: [0, 6]))

        #expect(!isDenseWeek(insight))
    }

    @Test("Day zero through day six qualifies")
    func dayZeroThroughSixQualifies() async throws {
        let insight = try await execute(items: items(onDays: [0, 1, 6]))

        #expect(isDenseWeek(insight))
    }

    @Test("A charge exactly seven calendar days later is excluded")
    func chargeAtSevenDaysIsExcluded() async throws {
        let insight = try await execute(items: items(onDays: [0, 6, 7]))

        #expect(!isDenseWeek(insight))
    }

    @Test("Dense week crosses a month boundary")
    func denseWeekAcrossMonthBoundary() async throws {
        let localCalendar = fixedCalendar(timeZoneID: "UTC")
        let localToday = date(2026, 1, 29, hour: 10, calendar: localCalendar)
        let insight = try await execute(
            items: items(onDays: [1, 3, 6], today: localToday, calendar: localCalendar),
            today: localToday,
            calendar: localCalendar
        )

        #expect(isDenseWeek(insight))
    }

    @Test("Dense week crosses a year boundary")
    func denseWeekAcrossYearBoundary() async throws {
        let localCalendar = fixedCalendar(timeZoneID: "UTC")
        let localToday = date(2025, 12, 29, hour: 10, calendar: localCalendar)
        let insight = try await execute(
            items: items(onDays: [1, 3, 6], today: localToday, calendar: localCalendar),
            today: localToday,
            calendar: localCalendar
        )

        #expect(isDenseWeek(insight))
    }

    @Test("Two same-day events and one nearby event form dense week without same-day attention")
    func denseWeekCanContainSameDayEvents() async throws {
        let insight = try await execute(items: [
            item(id: 1, nextChargeDate: day(1)),
            item(id: 2, nextChargeDate: day(1)),
            item(id: 3, nextChargeDate: day(3))
        ])

        #expect(!isSameDayAttention(insight))
        #expect(isDenseWeek(insight))
    }

    @Test("Paused, cancelled, archived, and expired finite items are excluded from dense week")
    func denseWeekLifecycleExclusions() async throws {
        let excluded: [RecurringItem] = [
            item(id: 3, nextChargeDate: day(5), status: .paused),
            item(id: 4, nextChargeDate: day(5), status: .cancelled),
            item(id: 5, nextChargeDate: day(5), status: .archived),
            item(id: 6, nextChargeDate: day(5), archivedAt: day(-1)),
            item(
                id: 7,
                nextChargeDate: day(-2),
                autoRenew: false,
                endDate: day(-1),
                status: .active
            )
        ]

        for excludedItem in excluded {
            let insight = try await execute(items: [
                item(id: 1, nextChargeDate: day(1)),
                item(id: 2, nextChargeDate: day(3)),
                excludedItem
            ])
            #expect(!isDenseWeek(insight))
        }
    }

    @Test("Stale recurring dates use effective rollover")
    func staleDatesRollForward() async throws {
        let insight = try await execute(items: [
            item(id: 1, billingCycle: .weekly, nextChargeDate: day(-13)),
            item(id: 2, billingCycle: .weekly, nextChargeDate: day(-11)),
            item(id: 3, billingCycle: .weekly, nextChargeDate: day(-9))
        ])

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week after effective rollover")
            return
        }
        #expect(details.firstChargeDate == calendar.startOfDay(for: day(1)))
        #expect(details.lastChargeDate == calendar.startOfDay(for: day(5)))
    }

    @Test("Weekly recurrence is not projected a second time")
    func weeklyItemIsNotRepeatedInsideHorizon() async throws {
        let insight = try await execute(items: [
            item(id: 1, billingCycle: .weekly, nextChargeDate: day(1)),
            item(id: 2, nextChargeDate: day(8)),
            item(id: 3, nextChargeDate: day(8))
        ])

        #expect(!isDenseWeek(insight))
        #expect(!isSameDayAttention(insight))
    }

    @Test("Dense-week window with the greatest count wins")
    func maximumCountWindowWins() async throws {
        let insight = try await execute(items: items(onDays: [1, 2, 3, 12, 13, 14, 15]))

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week")
            return
        }
        #expect(details.chargeCount == 4)
        #expect(details.firstChargeDate == calendar.startOfDay(for: day(12)))
    }

    @Test("Earliest dense-week window wins a count tie")
    func earliestWindowWinsTie() async throws {
        let insight = try await execute(items: items(onDays: [1, 2, 3, 12, 13, 14]))

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week")
            return
        }
        #expect(details.firstChargeDate == calendar.startOfDay(for: day(1)))
    }

    @Test("Dense-week ordering prefers shorter actual span after equal count and start")
    func shortestSpanTieBreak() {
        let start = calendar.startOfDay(for: today)
        let shorter = OverviewDenseWeekCandidateOrder(
            chargeCount: 3,
            windowStart: start,
            actualSpan: 2 * 24 * 60 * 60,
            itemIDs: [id(1), id(2), id(3)]
        )
        let longer = OverviewDenseWeekCandidateOrder(
            chargeCount: 3,
            windowStart: start,
            actualSpan: 4 * 24 * 60 * 60,
            itemIDs: [id(1), id(2), id(3)]
        )

        #expect(shorter.isPreferred(to: longer))
        #expect(!longer.isPreferred(to: shorter))
    }

    @Test("Dense-week final tie uses stable UUID sequence")
    func denseWeekUUIDTieBreak() {
        let start = calendar.startOfDay(for: today)
        let lowerIDs = OverviewDenseWeekCandidateOrder(
            chargeCount: 3,
            windowStart: start,
            actualSpan: 2 * 24 * 60 * 60,
            itemIDs: [id(1), id(2), id(3)]
        )
        let higherIDs = OverviewDenseWeekCandidateOrder(
            chargeCount: 3,
            windowStart: start,
            actualSpan: 2 * 24 * 60 * 60,
            itemIDs: [id(1), id(2), id(4)]
        )

        #expect(lowerIDs.isPreferred(to: higherIDs))
        #expect(!higherIDs.isPreferred(to: lowerIDs))
    }

    @Test("Complete mixed-currency dense-week total is converted")
    func denseWeekCompleteFXTotal() async throws {
        let insight = try await execute(
            items: [
                item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(1)),
                item(id: 2, amount: 100, nextChargeDate: day(3)),
                item(id: 3, amount: 200, nextChargeDate: day(5))
            ],
            exchangeRateSnapshot: snapshot(rates: ["RUB": 100])
        )

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week")
            return
        }
        #expect(details.total?.amount == 400)
    }

    @Test("Incomplete FX removes only the dense-week total")
    func denseWeekIncompleteFXReturnsNilTotal() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(1)),
            item(id: 2, amount: 100, nextChargeDate: day(3)),
            item(id: 3, amount: 200, nextChargeDate: day(5))
        ])

        guard case let .denseWeek(details)? = insight else {
            Issue.record("Expected dense week")
            return
        }
        #expect(details.total == nil)
        #expect(details.chargeCount == 3)
    }

    // MARK: - Annual Scale

    @Test("Annual multipliers match every supported standard recurrence")
    func annualStandardRecurrenceMultipliers() async throws {
        let cases: [(BillingCycle, Decimal)] = [
            (.weekly, 5_200),
            (.monthly, 1_200),
            (.quarterly, 400),
            (.semiannual, 200),
            (.annual, 100)
        ]

        for (index, testCase) in cases.enumerated() {
            let insight = try await execute(items: [
                item(
                    id: index + 1,
                    amount: 100,
                    billingCycle: testCase.0,
                    nextChargeDate: day(40)
                )
            ])
            #expect(annualTotal(in: insight)?.amount == testCase.1)
        }
    }

    @Test("Valid custom cycle uses Decimal 365 divided by days")
    func annualValidCustomCycle() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 10, billingCycle: .custom(days: 10), nextChargeDate: day(40))
        ])

        #expect(annualTotal(in: insight)?.amount == Decimal(365))
    }

    @Test("Invalid custom cycle never divides and prevents annual scale")
    func annualInvalidCustomCycle() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, billingCycle: .custom(days: 0), nextChargeDate: day(40))
        ])

        #expect(insight == nil)
    }

    @Test("Mixed recurrence annualizes each item independently")
    func annualMixedRecurrence() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, billingCycle: .monthly, nextChargeDate: day(40)),
            item(id: 2, amount: 1_000, billingCycle: .annual, nextChargeDate: day(40)),
            item(id: 3, amount: 50, billingCycle: .weekly, nextChargeDate: day(40))
        ])

        #expect(annualTotal(in: insight)?.amount == 4_800)
    }

    @Test("Annual calculation preserves Decimal precision")
    func annualDecimalPrecision() async throws {
        let amount = Decimal(1_299) / Decimal(100)
        let insight = try await execute(items: [
            item(id: 1, amount: amount, billingCycle: .monthly, nextChargeDate: day(40))
        ])

        #expect(annualTotal(in: insight)?.amount == amount * Decimal(12))
    }

    @Test("Same-currency annual total needs no FX")
    func annualSameCurrency() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: day(40)),
            item(id: 2, amount: 200, nextChargeDate: day(40))
        ])

        #expect(annualTotal(in: insight) == (try Money(amount: 3_600, currencyCode: "RUB")))
    }

    @Test("Complete mixed-currency annual scale converts before summing")
    func annualCompleteMixedCurrency() async throws {
        let insight = try await execute(
            items: [
                item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(40)),
                item(id: 2, amount: 100, nextChargeDate: day(40))
            ],
            exchangeRateSnapshot: snapshot(rates: ["RUB": 100])
        )

        #expect(annualTotal(in: insight)?.amount == 2_400)
    }

    @Test("Incomplete FX prevents annual scale")
    func annualIncompleteFXPreventsInsight() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 1, currencyCode: "USD", nextChargeDate: day(40)),
            item(id: 2, amount: 100, nextChargeDate: day(40))
        ])

        #expect(insight == nil)
    }

    @Test("Paused, cancelled, and archived items are excluded from annual scale")
    func annualLifecycleExclusions() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: day(40)),
            item(id: 2, amount: 1_000, nextChargeDate: day(40), status: .paused),
            item(id: 3, amount: 1_000, nextChargeDate: day(40), status: .cancelled),
            item(id: 4, amount: 1_000, nextChargeDate: day(40), status: .archived),
            item(id: 5, amount: 1_000, nextChargeDate: day(40), archivedAt: day(-1))
        ])

        #expect(annualTotal(in: insight)?.amount == 1_200)
    }

    @Test("Expired finite item is excluded from annual scale")
    func annualExpiredFiniteExclusion() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: day(40)),
            item(
                id: 2,
                amount: 1_000,
                nextChargeDate: day(-2),
                autoRenew: false,
                endDate: day(-1)
            )
        ])

        #expect(annualTotal(in: insight)?.amount == 1_200)
    }

    @Test("Trial with proven paid renewal terms contributes to annual scale")
    func validPaidRenewalTrialContributes() async throws {
        let renewalDate = day(10)
        let insight = try await execute(items: [
            item(
                id: 1,
                amount: 169,
                billingCycle: .monthly,
                nextChargeDate: renewalDate,
                status: .trial,
                trialEndDate: renewalDate
            )
        ])

        #expect(annualTotal(in: insight)?.amount == 2_028)
    }

    @Test("Ambiguous trial makes the full annual run-rate unavailable")
    func ambiguousTrialPreventsFalseAnnualScale() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: day(40)),
            item(
                id: 2,
                amount: 169,
                nextChargeDate: day(11),
                status: .trial,
                trialEndDate: day(10)
            )
        ])

        #expect(insight == nil)
    }

    @Test("No subscriptions returns nil")
    func noSubscriptionsReturnNil() async throws {
        #expect(try await execute(items: []) == nil)
    }

    @Test("Zero annual total returns nil")
    func zeroAnnualTotalReturnsNil() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 0, nextChargeDate: day(40))
        ])

        #expect(insight == nil)
    }

    @Test("Malformed currency never crashes or produces annual scale")
    func malformedCurrencyReturnsNil() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, currencyCode: "??", nextChargeDate: day(40))
        ])

        #expect(insight == nil)
    }

    @Test("Negative malformed amount never contributes")
    func negativeAmountReturnsNil() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: -100, nextChargeDate: day(40))
        ])

        #expect(insight == nil)
    }

    // MARK: - Selection Priority

    @Test("Trial attention beats same-day attention")
    func trialAttentionBeatsSameDayAttention() async throws {
        let insight = try await execute(items: [
            item(id: 1, status: .trial, trialEndDate: day(3)),
            item(id: 2, nextChargeDate: day(1)),
            item(id: 3, nextChargeDate: day(1)),
            item(id: 4, nextChargeDate: day(1))
        ])

        guard case .attention(.trialEnding)? = insight else {
            Issue.record("Expected trial attention")
            return
        }
    }

    @Test("Same-day attention beats dense week")
    func attentionBeatsDenseWeek() async throws {
        let insight = try await execute(items: sameDayItems(count: 3, dayOffset: 2))

        guard case .attention(.sameDayRenewals)? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
    }

    @Test("Dense week beats annual scale")
    func denseWeekBeatsAnnualScale() async throws {
        let insight = try await execute(items: items(onDays: [1, 3, 5]))

        guard case .denseWeek? = insight else {
            Issue.record("Expected dense week")
            return
        }
    }

    @Test("Annual scale is the fallback")
    func annualScaleIsFallback() async throws {
        let insight = try await execute(items: [
            item(id: 1, amount: 100, nextChargeDate: day(40))
        ])

        guard case .annualScale? = insight else {
            Issue.record("Expected annual scale")
            return
        }
    }

    @Test("No truthful insight returns nil")
    func noTruthfulInsightReturnsNil() async throws {
        let insight = try await execute(items: [
            item(
                id: 1,
                amount: 100,
                nextChargeDate: day(40),
                status: .trial,
                trialEndDate: nil
            )
        ])

        #expect(insight == nil)
    }

    // MARK: - Date Correctness

    @Test("Explicit timezone controls the three-day trial boundary")
    func explicitTimezoneControlsTrialBoundary() async throws {
        let tokyo = fixedCalendar(timeZoneID: "Asia/Tokyo")
        let localToday = date(2026, 8, 12, hour: 23, calendar: tokyo)
        let trialEnd = relativeDay(3, hour: 1, today: localToday, calendar: tokyo)
        let insight = try await execute(
            items: [
                item(
                    id: 1,
                    nextChargeDate: relativeDay(40, today: localToday, calendar: tokyo),
                    status: .trial,
                    trialEndDate: trialEnd,
                    today: localToday,
                    calendar: tokyo
                )
            ],
            today: localToday,
            calendar: tokyo
        )

        guard case let .attention(.trialEnding(details))? = insight else {
            Issue.record("Expected trial attention in the supplied timezone")
            return
        }
        #expect(details.trialEndDate == trialEnd)
    }

    @Test("Seven-day windows use calendar days across DST")
    func denseWeekAcrossDST() async throws {
        let losAngeles = fixedCalendar(timeZoneID: "America/Los_Angeles")
        let localToday = date(2026, 3, 7, hour: 10, calendar: losAngeles)
        let insight = try await execute(
            items: items(onDays: [0, 3, 6], today: localToday, calendar: losAngeles),
            today: localToday,
            calendar: losAngeles
        )

        #expect(isDenseWeek(insight))
    }

    @Test("Same-day grouping normalizes charge times with startOfDay")
    func startOfDayGroupsDifferentTimes() async throws {
        let insight = try await execute(items: [
            item(id: 1, nextChargeDate: day(2, hour: 1)),
            item(id: 2, nextChargeDate: day(2, hour: 12)),
            item(id: 3, nextChargeDate: day(2, hour: 23))
        ])

        guard case let .attention(.sameDayRenewals(details))? = insight else {
            Issue.record("Expected same-day attention")
            return
        }
        #expect(details.chargeDate == calendar.startOfDay(for: day(2)))
    }
}

// MARK: - Test Support

private extension OverviewInsightUseCaseTests {
    func execute(
        items: [RecurringItem],
        today: Date? = nil,
        calendar: Calendar? = nil,
        reportingCurrencyCode: String = "RUB",
        exchangeRateSnapshot: ExchangeRateSnapshot? = nil
    ) async throws -> OverviewInsight? {
        let repository = await OverviewInsightRepositoryStub(items: items)
        let useCase = OverviewInsightUseCase(repository: repository)
        return try await useCase.execute(
            today: today ?? self.today,
            calendar: calendar ?? self.calendar,
            reportingCurrencyCode: reportingCurrencyCode,
            exchangeRateSnapshot: exchangeRateSnapshot
        )
    }

    func item(
        id index: Int,
        title: String? = nil,
        amount: Decimal = 100,
        currencyCode: String = "RUB",
        billingCycle: BillingCycle = .monthly,
        nextChargeDate: Date? = nil,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        status: ItemStatus = .active,
        trialEndDate: Date? = nil,
        archivedAt: Date? = nil,
        today: Date? = nil,
        calendar: Calendar? = nil
    ) -> RecurringItem {
        let selectedToday = today ?? self.today
        let selectedCalendar = calendar ?? self.calendar
        let chargeDate = nextChargeDate
            ?? relativeDay(40, today: selectedToday, calendar: selectedCalendar)
        return RecurringItem(
            id: id(index),
            title: title ?? "Item \(index)",
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            startDate: relativeDay(-100, today: selectedToday, calendar: selectedCalendar),
            nextChargeDate: chargeDate,
            trialEndDate: trialEndDate,
            autoRenew: autoRenew,
            endDate: endDate,
            status: status,
            createdAt: relativeDay(-100, today: selectedToday, calendar: selectedCalendar),
            updatedAt: relativeDay(-1, today: selectedToday, calendar: selectedCalendar),
            archivedAt: archivedAt
        )
    }

    func items(
        onDays dayOffsets: [Int],
        today: Date? = nil,
        calendar: Calendar? = nil
    ) -> [RecurringItem] {
        let selectedToday = today ?? self.today
        let selectedCalendar = calendar ?? self.calendar
        return dayOffsets.enumerated().map { index, dayOffset in
            item(
                id: index + 1,
                nextChargeDate: relativeDay(
                    dayOffset,
                    today: selectedToday,
                    calendar: selectedCalendar
                ),
                today: selectedToday,
                calendar: selectedCalendar
            )
        }
    }

    func sameDayItems(count: Int, dayOffset: Int) -> [RecurringItem] {
        (1...count).map { index in
            item(id: index, nextChargeDate: day(dayOffset))
        }
    }

    func isSameDayAttention(_ insight: OverviewInsight?) -> Bool {
        guard case .attention(.sameDayRenewals)? = insight else { return false }
        return true
    }

    func isDenseWeek(_ insight: OverviewInsight?) -> Bool {
        guard case .denseWeek? = insight else { return false }
        return true
    }

    func annualTotal(in insight: OverviewInsight?) -> Money? {
        guard case let .annualScale(total)? = insight else { return nil }
        return total
    }

    func day(_ offset: Int, hour: Int = 12) -> Date {
        relativeDay(offset, hour: hour, today: today, calendar: calendar)
    }

    func relativeDay(
        _ offset: Int,
        hour: Int = 12,
        today: Date,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: today)
        let target = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: target) ?? target
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
        hour: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components) ?? .distantPast
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
                date: day(-1),
                rates: rates,
                fetchedAt: day(-1)
            ),
            freshness: .fresh
        )
    }
}

private enum OverviewInsightRepositoryStubError: Error {
    case unsupportedWrite
}

@MainActor
private final class OverviewInsightRepositoryStub: RecurringItemRepository {
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
        throw OverviewInsightRepositoryStubError.unsupportedWrite
    }

    func update(_ item: RecurringItem) throws {
        throw OverviewInsightRepositoryStubError.unsupportedWrite
    }

    func delete(id: UUID) throws {
        throw OverviewInsightRepositoryStubError.unsupportedWrite
    }

    func saveAll(_ items: [RecurringItem]) throws {
        throw OverviewInsightRepositoryStubError.unsupportedWrite
    }

    func deleteAll() throws {
        throw OverviewInsightRepositoryStubError.unsupportedWrite
    }
}
