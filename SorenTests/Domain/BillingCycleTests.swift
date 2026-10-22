import Testing
import Foundation
@testable import Soren

@Suite("BillingCycle — multipliers and helpers")
struct BillingCycleTests {

    @Test("Weekly multiplier uses the annual 365/7 basis")
    func weeklyMultiplier() throws {
        #expect(try BillingCycle.weekly.monthlyMultiplier == Decimal(365) / 7 / 12)
    }

    @Test("Monthly multiplier is exactly 1")
    func monthlyMultiplier() throws {
        #expect(try BillingCycle.monthly.monthlyMultiplier == 1)
    }

    @Test("Annual multiplier is approximately 1/12")
    func annualMultiplier() throws {
        #expect(try BillingCycle.annual.monthlyMultiplier == Decimal(1) / 12)
    }

    @Test("Custom 30-day cycle uses 365 days per year")
    func custom30Days() throws {
        #expect(try BillingCycle.custom(days: 30).monthlyMultiplier == Decimal(365) / 30 / 12)
    }

    @Test("Custom 60-day cycle uses 365 days per year")
    func custom60Days() throws {
        #expect(try BillingCycle.custom(days: 60).monthlyMultiplier == Decimal(365) / 60 / 12)
    }

    @Test("Custom 1-day cycle uses the annual basis")
    func custom1Day() throws {
        #expect(try BillingCycle.custom(days: 1).monthlyMultiplier == Decimal(365) / 12)
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
