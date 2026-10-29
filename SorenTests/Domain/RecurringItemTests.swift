import Testing
import Foundation
@testable import Soren

private let recurringReferenceDay = Date(timeIntervalSince1970: 1_786_752_000)

@Suite("RecurringItem — domain logic")
struct RecurringItemTests {

    // MARK: - Monthly Equivalent

    @Test("Weekly normalization preserves Decimal precision from the annual basis")
    func monthlyEquivalentWeekly() throws {
        let item = RecurringItem.stub(amount: 100, cycle: .weekly)
        let expectedAmount = try #require(
            Decimal(
                string: "434.523809523809523809523809523809",
                locale: Locale(identifier: "en_US_POSIX")
            )
        )
        let tolerance = try #require(Decimal(string: "0.000000000000000000000000000001"))
        #expect(abs(try item.monthlyEquivalent - expectedAmount) < tolerance)
    }

    @Test("Monthly equivalent for monthly billing equals amount exactly")
    func monthlyEquivalentMonthly() throws {
        let item = RecurringItem.stub(amount: 299, cycle: .monthly)
        #expect(try item.monthlyEquivalent == 299)
    }

    @Test("Monthly equivalent for annual billing divides by 12")
    func monthlyEquivalentAnnual() throws {
        let item = RecurringItem.stub(amount: 1200, cycle: .annual)
        // 1200 * (1/12) = 100
        #expect(try item.monthlyEquivalent == 100)
    }

    @Test("Monthly equivalent for custom cycle with small number of days")
    func monthlyEquivalentCustomShort() throws {
        let item = RecurringItem.stub(amount: 100, cycle: .custom(days: 1))
        #expect(try item.monthlyEquivalent == Decimal(36_500) / 12)
    }

    // MARK: - Annual Equivalent

    @Test("Annual equivalent is 12x monthly equivalent")
    func annualEquivalent() throws {
        let item = RecurringItem.stub(amount: 100, cycle: .monthly)
        #expect(try item.annualEquivalent == 1200)
    }

    @Test("Exact annual basis and monthly equivalents", arguments: [
        (BillingCycle.annual, 1200, 1200, 100),
        (.quarterly, 600, 2400, 200), (.semiannual, 600, 1200, 100),
        (.monthly, 124, 1488, 124), (.custom(days: 365), 100, 100, 0)
    ])
    func exactAnnualBasis(example: (BillingCycle, Int, Int, Int)) throws {
        let item = RecurringItem.stub(amount: Decimal(example.1), cycle: example.0)
        #expect(try item.annualEquivalent == Decimal(example.2))
        if example.3 > 0 { #expect(try item.monthlyEquivalent == Decimal(example.3)) }
        #expect(item.amount == Decimal(example.1))
    }

    @Test("Weekly and custom-seven normalization agree without drift")
    func weeklyAndCustomAgree() throws {
        let weekly = RecurringItem.stub(amount: 100, cycle: .weekly)
        let custom = RecurringItem.stub(amount: 100, cycle: .custom(days: 7))
        #expect(try weekly.annualEquivalent == custom.annualEquivalent)
        #expect(try weekly.monthlyEquivalent == custom.monthlyEquivalent)
        let expected = try #require(Decimal(string: "5214.285714285714285714285714285714"))
        let tolerance = try #require(Decimal(string: "0.000000000000000000000000000001"))
        #expect(abs(try weekly.annualEquivalent - expected) < tolerance)
    }

    @Test("Custom cycles and fractional amounts retain unrounded Decimal contributions", arguments: [1, 30, 60, 365])
    func customPrecision(days: Int) throws {
        let amount = try #require(Decimal(string: "0.015"))
        let item = RecurringItem.stub(amount: amount, cycle: .custom(days: days))
        #expect(try item.annualEquivalent == amount * 365 / Decimal(days))
        #expect(try item.monthlyEquivalent == item.annualEquivalent / 12)
    }

    @Test("Every normalization API rejects invalid custom cycles before division", arguments: [0, -1])
    func invalidNormalization(days: Int) {
        let item = RecurringItem.stub(amount: 100, cycle: .custom(days: days))
        let error = BillingCycle.ValidationError.invalidCustomDays(days)
        #expect(throws: error) { try item.billingCycle.monthlyMultiplier }
        #expect(throws: error) { try item.annualEquivalent }
        #expect(throws: error) { try item.monthlyEquivalent }
    }

    // MARK: - isDue

    @Test("isDue returns true when charge is within window")
    func isDueWithinWindow() throws {
        let threeDaysOut = BillingCivilDay.calendar.date(byAdding: .day, value: 3, to: recurringReferenceDay)!
        let item = RecurringItem.stub(nextChargeDate: threeDaysOut)
        #expect(try item.isDue(within: 7, from: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)))
    }

    @Test("isDue returns false when charge is outside window")
    func isDueOutsideWindow() throws {
        let tenDaysOut = BillingCivilDay.calendar.date(byAdding: .day, value: 10, to: recurringReferenceDay)!
        let item = RecurringItem.stub(nextChargeDate: tenDaysOut)
        #expect(try item.isDue(within: 7, from: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    @Test("isDue returns false for past charge dates")
    func isDuePastDate() throws {
        let yesterday = BillingCivilDay.calendar.date(byAdding: .day, value: -1, to: recurringReferenceDay)!
        let item = RecurringItem.stub(nextChargeDate: yesterday)
        #expect(try item.isDue(within: 7, from: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    @Test("isDue with zero-day window: only today counts")
    func isDueZeroDayWindow() throws {
        // Pin both the charge date and the reference date to avoid sub-millisecond drift.
        let anchor = recurringReferenceDay
        let item = RecurringItem.stub(nextChargeDate: anchor)
        #expect(try item.isDue(within: 0, from: BillingCivilDay.civilDate(fromCanonicalDate: anchor)))
    }

    @Test("isDue with negative window returns false always")
    func isDueNegativeWindow() throws {
        let item = RecurringItem.stub(nextChargeDate: recurringReferenceDay)
        #expect(try item.isDue(within: -1, from: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    // MARK: - Trial

    @Test("isActiveTrial true when status is trial and date is future")
    func isActiveTrialTrue() throws {
        let future = BillingCivilDay.calendar.date(byAdding: .day, value: 7, to: recurringReferenceDay)!
        let item = RecurringItem.stub(status: .trial, trialEndDate: future)
        #expect(try item.isActiveTrial(on: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)))
    }

    @Test("isActiveTrial false when status is active even with trialEndDate")
    func isActiveTrialWrongStatus() throws {
        let future = BillingCivilDay.calendar.date(byAdding: .day, value: 7, to: recurringReferenceDay)!
        let item = RecurringItem.stub(status: .active, trialEndDate: future)
        #expect(try item.isActiveTrial(on: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    @Test("isActiveTrial false when trialEndDate is in the past")
    func isActiveTrialExpired() throws {
        let past = BillingCivilDay.calendar.date(byAdding: .day, value: -1, to: recurringReferenceDay)!
        let item = RecurringItem.stub(status: .trial, trialEndDate: past)
        #expect(try item.isActiveTrial(on: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    @Test("isActiveTrial false when trialEndDate is nil")
    func isActiveTrialNilDate() throws {
        let item = RecurringItem.stub(status: .trial, trialEndDate: nil)
        #expect(try item.isActiveTrial(on: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == false)
    }

    @Test("daysUntilTrialEnd returns nil when not a trial")
    func daysUntilTrialEndNotTrial() throws {
        let item = RecurringItem.stub(status: .active)
        #expect(try item.daysUntilTrialEnd(from: BillingCivilDay.civilDate(fromCanonicalDate: recurringReferenceDay)) == nil)
    }

    // MARK: - providerName fallback

    @Test("providerName falls back to title when empty string given")
    func providerNameFallback() throws {
        let item = RecurringItem(
            title: "Netflix",
            providerName: "",
            amount: 999,
            nextChargeDate: recurringReferenceDay
        )
        #expect(item.providerName == "Netflix")
    }

    @Test("providerName uses provided value when non-empty")
    func providerNameProvided() throws {
        let item = RecurringItem(
            title: "Netflix",
            providerName: "Netflix Inc.",
            amount: 999,
            nextChargeDate: recurringReferenceDay
        )
        #expect(item.providerName == "Netflix Inc.")
    }

    // MARK: - Status helpers

    @Test("countsInTotals is false for archived items")
    func archivedNotCountedInTotals() throws {
        let item = RecurringItem.stub(status: .archived)
        #expect(!item.status.countsInTotals)
    }

    @Test("countsInTotals is true for overdue items")
    func overdueCountsInTotals() throws {
        let item = RecurringItem.stub(status: .overdue)
        #expect(item.status.countsInTotals)
    }

    @Test("requiresAttention is true for failed payment")
    func failedRequiresAttention() throws {
        let item = RecurringItem.stub(status: .failed)
        #expect(item.status.requiresAttention)
    }

    @Test("requiresAttention is false for paused item")
    func pausedNoAttention() throws {
        let item = RecurringItem.stub(status: .paused)
        #expect(!item.status.requiresAttention)
    }
}

// MARK: - Stub Helpers

private extension RecurringItem {
    static func stub(
        title: String = "Test Item",
        amount: Decimal = 100,
        cycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        nextChargeDate: Date = BillingCivilDay.calendar.date(byAdding: .day, value: 7, to: recurringReferenceDay)!,
        trialEndDate: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            amount: amount,
            billingCycle: cycle,
            nextChargeDate: nextChargeDate,
            trialEndDate: trialEndDate,
            status: status
        )
    }
}

extension RecurringItemTests {
    @Test("Renewal decision defaults are opt-in")
    func renewalDecisionDefaults() throws {
        let item = try canonicalTestItem()
        #expect(item.renewalDecisionDeadline == nil)
        #expect(!item.renewalDecisionReminderEnabled)
        try item.validateRenewalDecision()
    }

    @Test("Decision day is independent, may be past, and survives value copies", arguments: [2020, 2026, 2027])
    func renewalDecisionValueSemantics(year: Int) throws {
        var source = try canonicalTestItem()
        source.trialEndDate = source.nextChargeDate
        var copy = source
        copy.renewalDecisionDeadline = try CivilDate(year: year, month: 3, day: 29)
        copy.renewalDecisionReminderEnabled = true
        try copy.validateRenewalDecision()
        #expect(source.renewalDecisionDeadline == nil)
        #expect(copy.nextChargeDate == source.nextChargeDate && copy.startDate == source.startDate)
        #expect(copy.trialEndDate == source.trialEndDate && copy.autoRenew == source.autoRenew)
        #expect(copy.status == source.status && copy.endDate == source.endDate)
        var edited = copy
        edited.note = "An ordinary edit"
        #expect(edited.renewalDecisionDeadline == copy.renewalDecisionDeadline)
        #expect(edited.renewalDecisionReminderEnabled)
        #expect(Set([copy, edited]).count == 2)
        copy.renewalDecisionDeadline = nil
        #expect(throws: RecurringItem.RenewalDecisionValidationError.reminderRequiresDeadline) {
            try copy.validateRenewalDecision()
        }
    }
}
