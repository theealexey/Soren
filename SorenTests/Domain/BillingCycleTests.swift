import Testing
import Foundation
@testable import Soren

@Suite("BillingCycle — multipliers and helpers")
struct BillingCycleTests {

    @Test("Weekly multiplier is approximately 4.33")
    func weeklyMultiplier() {
        #expect(BillingCycle.weekly.monthlyMultiplier == Decimal(string: "4.33")!)
    }

    @Test("Monthly multiplier is exactly 1")
    func monthlyMultiplier() {
        #expect(BillingCycle.monthly.monthlyMultiplier == 1)
    }

    @Test("Annual multiplier is approximately 1/12")
    func annualMultiplier() {
        let expected = Decimal(string: "0.0833")!
        #expect(BillingCycle.annual.monthlyMultiplier == expected)
    }

    @Test("Custom 30-day cycle has multiplier of 1")
    func custom30Days() {
        #expect(BillingCycle.custom(days: 30).monthlyMultiplier == 1)
    }

    @Test("Custom 60-day cycle has multiplier of 0.5")
    func custom60Days() {
        #expect(BillingCycle.custom(days: 60).monthlyMultiplier == Decimal(string: "0.5")!)
    }

    @Test("Custom 1-day cycle produces large multiplier (30)")
    func custom1Day() {
        #expect(BillingCycle.custom(days: 1).monthlyMultiplier == 30)
    }

    @Test("isLongCycle is true for annual")
    func isLongCycleAnnual() {
        #expect(BillingCycle.annual.isLongCycle)
    }

    @Test("isLongCycle is false for monthly")
    func isLongCycleMonthly() {
        #expect(!BillingCycle.monthly.isLongCycle)
    }

    @Test("isLongCycle is true for quarterly")
    func isLongCycleQuarterly() {
        #expect(BillingCycle.quarterly.isLongCycle)
    }

    @Test("isLongCycle is false for weekly")
    func isLongCycleWeekly() {
        #expect(!BillingCycle.weekly.isLongCycle)
    }

    @Test("approximateDays for weekly is 7")
    func approximateDaysWeekly() {
        #expect(BillingCycle.weekly.approximateDays == 7)
    }

    @Test("approximateDays for custom matches parameter")
    func approximateDaysCustom() {
        #expect(BillingCycle.custom(days: 42).approximateDays == 42)
    }

    @Test("All CaseIterable cases exclude custom")
    func caseIterableExcludesCustom() {
        let cases = BillingCycle.allCases
        #expect(cases.count == 5)
        #expect(!cases.contains(where: {
            if case .custom = $0 { return true }
            return false
        }))
    }
}
