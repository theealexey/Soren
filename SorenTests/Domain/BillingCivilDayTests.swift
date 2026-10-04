import Foundation
import Testing
@testable import Soren

struct BillingCivilDayTests {
    @Test(arguments: [(2026, 8, 15), (2024, 2, 29), (2026, 12, 31), (2027, 1, 1)])
    func roundTripAndCodecEquivalence(parts: (Int, Int, Int)) throws {
        let civil = try CivilDate(year: parts.0, month: parts.1, day: parts.2)
        let date = try BillingCivilDay.canonicalDate(for: civil)
        #expect(try BillingCivilDay.civilDate(fromCanonicalDate: date) == civil)
        #expect(try CivilDateStorageCodec().encode(civil) == date)
        #expect(BillingCivilDay.calendar.component(.hour, from: date) == 0)
    }

    @Test func strictInverseRejectsTimeComponent() throws {
        let date = try canonicalTestDay(15).addingTimeInterval(1)
        #expect(throws: BillingCivilDayError.nonCanonicalDate(date)) {
            try BillingCivilDay.civilDate(fromCanonicalDate: date)
        }
    }

    @Test func invalidInstantRejected() {
        let date = Date(timeIntervalSinceReferenceDate: .infinity)
        #expect(throws: BillingCivilDayError.invalidInstant(date)) {
            try BillingCivilDay.civilDate(containing: date, in: .gmt)
        }
    }

    @Test(arguments: [("Europe/Stockholm", 15), ("America/Los_Angeles", 14)])
    func explicitInstantInterpretation(input: (String, Int)) throws {
        let zone = try #require(TimeZone(identifier: input.0))
        let instant = try canonicalTestDay(15)
        let expected = try CivilDate(year: 2026, month: 8, day: input.1)
        #expect(try BillingCivilDay.civilDate(containing: instant, in: zone) == expected)
        // Canonical inverse is independent of either interpretation calendar.
        #expect(try BillingCivilDay.civilDate(fromCanonicalDate: instant).day == 15)
    }
}

struct RecurringItemCivilDayTests {
    @Test func suppliedDayControlsTrialBoundary() throws {
        var item = try canonicalTestItem()
        item.status = .trial
        item.trialEndDate = try canonicalTestDay(16)
        let before = try CivilDate(year: 2026, month: 8, day: 15)
        let boundary = try CivilDate(year: 2026, month: 8, day: 16)
        #expect(try item.isActiveTrial(on: before))
        #expect(try item.daysUntilTrialEnd(from: before) == 1)
        #expect(try item.isActiveTrial(on: boundary) == false)
        #expect(try item.daysUntilTrialEnd(from: boundary) == nil)
        item.status = .active
        #expect(try item.isActiveTrial(on: before) == false)
    }

    @Test func finiteEndIsInclusive() throws {
        var item = try canonicalTestItem()
        item.autoRenew = false
        item.endDate = try canonicalTestDay(16)
        let end = try CivilDate(year: 2026, month: 8, day: 16)
        let after = try CivilDate(year: 2026, month: 8, day: 17)
        #expect(try item.renewalDisplay(relativeTo: end) == .endingSoon(daysLeft: 0))
        #expect(try item.isExpired(on: end) == false)
        #expect(try item.isExpired(on: after))
        item.autoRenew = true
        #expect(try item.isExpired(on: after) == false)
    }

    @Test func dueWindowAndDisplayRolloverAreExplicit() throws {
        var item = try canonicalTestItem()
        item.billingCycle = .weekly
        let today = try CivilDate(year: 2026, month: 8, day: 16)
        #expect(try item.daysUntilNextCharge(from: today) == -1)
        #expect(try item.isDue(within: 7, from: today) == false)
        #expect(try item.effectiveNextChargeDate(relativeTo: today) == canonicalTestDay(22))
        item.status = .paused
        #expect(try item.effectiveNextChargeDate(relativeTo: today) == item.nextChargeDate)
        item.status = .active
        item.autoRenew = false
        #expect(try item.effectiveNextChargeDate(relativeTo: today) == item.nextChargeDate)
    }

    @Test func helpersRejectRawDateRatherThanNormalizing() throws {
        var item = try canonicalTestItem()
        item.nextChargeDate = item.nextChargeDate.addingTimeInterval(1)
        let today = try CivilDate(year: 2026, month: 8, day: 15)
        #expect(throws: BillingCivilDayError.self) { try item.daysUntilNextCharge(from: today) }
    }
}

// Explicit canonical fixtures shared only by the focused Domain/Data integration tests.
func canonicalTestDay(_ day: Int = 15) throws -> Date {
    try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 8, day: day))
}

func canonicalTestItem() throws -> RecurringItem {
    try RecurringItem(title: "Canonical", amount: 100, startDate: canonicalTestDay(1), nextChargeDate: canonicalTestDay())
}
