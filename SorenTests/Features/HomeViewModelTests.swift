import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Home ViewModel Tests (Aggressive)

/// Adversarial tests for HomeViewModel and its Use Cases.
/// Goal: break the dashboard logic, not just confirm it works on golden-path data.

@Suite("HomeViewModel")
@MainActor
struct HomeViewModelTests {

    // MARK: - Helpers

    private func makeRepo() throws -> SwiftDataRecurringItemRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataRecurringItemRepository(context: container.mainContext)
    }

    private func makeViewModel(repo: SwiftDataRecurringItemRepository) -> HomeViewModel {
        HomeViewModel(
            getDashboardSummary: GetDashboardSummary(repository: repo),
            getUpcomingCharges: GetUpcomingCharges(repository: repo),
            getActiveTrials: GetActiveTrials(repository: repo)
        )
    }


    private func makeItem(
        title: String = "Test",
        amount: Decimal = 299,
        currencyCode: String = "RUB",
        billingCycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        nextCharge: Date? = nil,
        trialEndDate: Date? = nil,
        category: ItemCategory = .video
    ) -> RecurringItem {
        RecurringItem(
            title: title,
            category: category,
            amount: amount,
            currencyCode: currencyCode,
            billingCycle: billingCycle,
            nextChargeDate: nextCharge ?? Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            trialEndDate: trialEndDate,
            status: status
        )
    }

    // MARK: - Empty State

    @Test("Empty repository produces empty summary")
    func emptyRepo() throws {
        let repo = try makeRepo()
        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.summary == .empty)
        #expect(vm.upcomingCharges.isEmpty)
        #expect(vm.activeTrials.isEmpty)
        #expect(vm.isLoaded)
        #expect(!vm.hasError)
    }

    // MARK: - Summary Calculations

    @Test("Monthly total aggregates only active items")
    func monthlyTotalExcludesArchived() throws {
        let repo = try makeRepo()

        let active = makeItem(title: "A", amount: 100, status: .active)
        let trial = makeItem(title: "B", amount: 200, status: .trial,
                             trialEndDate: Calendar.current.date(byAdding: .day, value: 10, to: .now))
        let archived = makeItem(title: "C", amount: 9999, status: .archived)
        let cancelled = makeItem(title: "D", amount: 5000, status: .cancelled)

        try repo.save(active)
        try repo.save(trial)
        try repo.save(archived)
        try repo.save(cancelled)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        // Only active + trial should count (both are monthly, multiplier = 1)
        #expect(vm.summary.monthlyTotal == 300)
        #expect(vm.summary.yearlyProjection == 3600)
        #expect(vm.summary.activeItemCount == 2)
    }

    @Test("Annual item monthly equivalent is correct")
    func annualItemEquivalent() throws {
        let repo = try makeRepo()

        // 1200 RUB/year → 1200 * 0.0833 = 99.96/month
        let annual = makeItem(title: "Annual", amount: 1200, billingCycle: .annual)
        try repo.save(annual)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        // 1200 * 0.0833 = 99.96
        #expect(vm.summary.monthlyTotal == 1200 * Decimal(string: "0.0833")!)
    }

    @Test("Zero-amount item doesn't break totals")
    func zeroAmountItem() throws {
        let repo = try makeRepo()
        let free = makeItem(title: "Free tier", amount: 0)
        try repo.save(free)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.summary.monthlyTotal == 0)
        #expect(vm.summary.activeItemCount == 1)
        #expect(vm.isLoaded)
    }

    @Test("Trial count only includes trial status items")
    func trialCountAccuracy() throws {
        let repo = try makeRepo()

        let trial1 = makeItem(title: "T1", status: .trial,
                              trialEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now))
        let trial2 = makeItem(title: "T2", status: .trial,
                              trialEndDate: Calendar.current.date(byAdding: .day, value: 2, to: .now))
        let active = makeItem(title: "A", status: .active)

        try repo.save(trial1)
        try repo.save(trial2)
        try repo.save(active)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.summary.activeTrialCount == 2)
    }

    // MARK: - Upcoming Charges

    @Test("Upcoming charges only includes items within 7-day window")
    func upcomingWindowBoundary() throws {
        let repo = try makeRepo()

        let tomorrow = makeItem(title: "Tomorrow",
                                nextCharge: Calendar.current.date(byAdding: .day, value: 1, to: .now))
        let day7 = makeItem(title: "Day7",
                            nextCharge: Calendar.current.date(byAdding: .day, value: 7, to: .now))
        let day8 = makeItem(title: "Day8",
                            nextCharge: Calendar.current.date(byAdding: .day, value: 8, to: .now))

        try repo.save(tomorrow)
        try repo.save(day7)
        try repo.save(day8)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        let titles = Set(vm.upcomingCharges.map(\.title))
        #expect(titles.contains("Tomorrow"))
        #expect(titles.contains("Day7"))
        #expect(!titles.contains("Day8"))
    }

    @Test("Past-due items appear in upcoming if repository returns them")
    func pastDueHandling() throws {
        let repo = try makeRepo()

        let overdue = makeItem(title: "Overdue",
                               nextCharge: Calendar.current.date(byAdding: .day, value: -2, to: .now))
        try repo.save(overdue)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        // Past items may or may not appear depending on repository logic
        // The key test: ViewModel doesn't crash on negative daysUntilNextCharge
        #expect(vm.isLoaded)
        #expect(!vm.hasError)
    }

    // MARK: - Active Trials

    @Test("Active trials filters correctly — expired trials excluded")
    func expiredTrialsExcluded() throws {
        let repo = try makeRepo()

        let activeTrial = makeItem(
            title: "Active Trial", status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)
        )
        let expiredTrial = makeItem(
            title: "Expired Trial", status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)
        )
        let activeNoTrial = makeItem(title: "Regular", status: .active)

        try repo.save(activeTrial)
        try repo.save(expiredTrial)
        try repo.save(activeNoTrial)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.activeTrials.count == 1)
        #expect(vm.activeTrials.first?.title == "Active Trial")
    }

    @Test("Trial with nil trialEndDate is not an active trial")
    func trialWithNilEndDate() throws {
        let repo = try makeRepo()

        let brokenTrial = makeItem(title: "Broken", status: .trial, trialEndDate: nil)
        try repo.save(brokenTrial)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.activeTrials.isEmpty)
    }

    // MARK: - Load Idempotency

    @Test("Multiple loads don't duplicate data")
    func multipleLoads() throws {
        let repo = try makeRepo()
        let item = makeItem(title: "Single", amount: 100)
        try repo.save(item)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()
        vm.loadLocalData()
        vm.loadLocalData()

        #expect(vm.summary.activeItemCount == 1)
        #expect(vm.summary.monthlyTotal == 100)
    }

    // MARK: - Mixed Currency Stress

    @Test("Dashboard handles mixed currencies without crashing")
    func mixedCurrencies() throws {
        let repo = try makeRepo()

        let rub = makeItem(title: "RUB item", amount: 299, currencyCode: "RUB")
        let usd = makeItem(title: "USD item", amount: 9.99, currencyCode: "USD")
        let eur = makeItem(title: "EUR item", amount: 14.99, currencyCode: "EUR")

        try repo.save(rub)
        try repo.save(usd)
        try repo.save(eur)

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        // monthlyTotal sums raw amounts (no conversion) — this is expected for V1
        #expect(vm.summary.monthlyTotal == 299 + Decimal(string: "9.99")! + Decimal(string: "14.99")!)
        #expect(vm.summary.activeItemCount == 3)
        #expect(vm.isLoaded)
    }

    // MARK: - Large Dataset

    @Test("Handles 100 items without issue")
    func largeDataset() throws {
        let repo = try makeRepo()

        for i in 0..<100 {
            let item = makeItem(
                title: "Item \(i)",
                amount: Decimal(i + 1),
                nextCharge: Calendar.current.date(byAdding: .day, value: i % 10, to: .now)
            )
            try repo.save(item)
        }

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.summary.activeItemCount == 100)
        #expect(vm.isLoaded)
        // Sum of 1..100 = 5050
        #expect(vm.summary.monthlyTotal == 5050)
    }

    // MARK: - All Statuses Survive Load

    @Test("Every ItemStatus survives through ViewModel load")
    func allStatusesSurviveLoad() throws {
        let repo = try makeRepo()

        let statuses: [ItemStatus] = [
            .active, .dueSoon, .dueToday, .overdue,
            .trial, .failed, .cancelled, .paused, .archived
        ]

        for (i, status) in statuses.enumerated() {
            let item = makeItem(
                title: "Status \(status.rawValue)",
                amount: Decimal(10 * (i + 1)),
                status: status,
                trialEndDate: status == .trial
                    ? Calendar.current.date(byAdding: .day, value: 5, to: .now)
                    : nil
            )
            try repo.save(item)
        }

        let vm = makeViewModel(repo: repo)
        vm.loadLocalData()

        #expect(vm.isLoaded)
        #expect(!vm.hasError)
        // archived + cancelled + paused are filtered out of fetchActive
        // Active count depends on repository's fetchActive logic
        #expect(vm.summary.activeItemCount > 0)
    }
}

// MARK: - Use Case Isolation Tests

@Suite("GetDashboardSummary")
@MainActor
struct GetDashboardSummaryTests {

    private func makeRepo() throws -> SwiftDataRecurringItemRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataRecurringItemRepository(context: container.mainContext)
    }

    @Test("Empty repo returns empty summary")
    func emptyReturnsEmpty() throws {
        let repo = try makeRepo()
        let summary = try GetDashboardSummary(repository: repo).execute()
        #expect(summary == .empty)
    }

    @Test("Yearly projection is exactly 12x monthly")
    func yearlyIs12xMonthly() throws {
        let repo = try makeRepo()
        let item = RecurringItem(
            title: "Test",
            amount: 333,
            nextChargeDate: .now
        )
        try repo.save(item)

        let summary = try GetDashboardSummary(repository: repo).execute()
        #expect(summary.yearlyProjection == summary.monthlyTotal * 12)
    }
}

@Suite("GetUpcomingCharges")
@MainActor
struct GetUpcomingChargesTests {

    private func makeRepo() throws -> SwiftDataRecurringItemRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataRecurringItemRepository(context: container.mainContext)
    }

    @Test("Custom day window works")
    func customDayWindow() throws {
        let repo = try makeRepo()

        let day3 = RecurringItem(
            title: "Day3",
            amount: 100,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!
        )
        let day10 = RecurringItem(
            title: "Day10",
            amount: 100,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        )

        try repo.save(day3)
        try repo.save(day10)

        let within5 = try GetUpcomingCharges(repository: repo).execute(days: 5)
        #expect(within5.count == 1)
        #expect(within5.first?.title == "Day3")

        let within15 = try GetUpcomingCharges(repository: repo).execute(days: 15)
        #expect(within15.count == 2)
    }

    @Test("Zero day window returns nothing")
    func zeroDayWindow() throws {
        let repo = try makeRepo()
        let item = RecurringItem(
            title: "Tomorrow",
            amount: 100,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        )
        try repo.save(item)

        let result = try GetUpcomingCharges(repository: repo).execute(days: 0)
        #expect(result.isEmpty)
    }
}

@Suite("GetActiveTrials")
@MainActor
struct GetActiveTrialsTests {

    private func makeRepo() throws -> SwiftDataRecurringItemRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataRecurringItemRepository(context: container.mainContext)
    }

    @Test("Only trial status with future trialEndDate qualifies")
    func onlyActiveTrials() throws {
        let repo = try makeRepo()

        // Active trial — should appear
        let good = RecurringItem(
            title: "Good Trial",
            amount: 0,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 7, to: .now)!,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            status: .trial
        )

        // Expired trial — should not appear
        let expired = RecurringItem(
            title: "Expired",
            amount: 0,
            nextChargeDate: .now,
            trialEndDate: Calendar.current.date(byAdding: .day, value: -1, to: .now),
            status: .trial
        )

        // Active but not trial status — should not appear
        let notTrial = RecurringItem(
            title: "Not Trial",
            amount: 100,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now),
            status: .active
        )

        try repo.save(good)
        try repo.save(expired)
        try repo.save(notTrial)

        let result = try GetActiveTrials(repository: repo).execute()
        #expect(result.count == 1)
        #expect(result.first?.title == "Good Trial")
    }
}
