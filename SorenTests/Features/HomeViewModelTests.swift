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
            getUpcomingCharges: GetUpcomingCharges(repository: repo),
            getActiveTrials: GetActiveTrials(repository: repo),
            preferences: UserPreferencesRepository()
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

    @Test("Empty repository produces empty landscape")
    func emptyRepo() throws {
        let repo = try makeRepo()
        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.isLoaded)
        #expect(!vm.hasError)
        #expect(vm.landscapePoints.count == 30)
        #expect(vm.landscapePoints.allSatisfy { $0.chargeCount == 0 })
        #expect(vm.insights.isEmpty)
        #expect(vm.upcomingCharges.isEmpty)
    }

    // MARK: - Landscape Charges

    @Test("Active items appear in landscape at correct day offset")
    func activeItemsPopulateLandscape() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(title: "A", amount: 100, status: .active))
        try repo.save(makeItem(title: "B", amount: 200, status: .active))

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.isLoaded)
        #expect(vm.landscapePoints[3].chargeCount == 2)
        #expect(vm.landscapePoints[3].rawTotal == 300)
    }

    @Test("Truly archived items (archivedAt set) excluded from landscape")
    func archivedItemsExcludedFromLandscape() throws {
        let repo = try makeRepo()
        let active = makeItem(title: "Active", amount: 100)
        let archived = RecurringItem(
            title: "Archived",
            amount: 9999,
            currencyCode: "RUB",
            nextChargeDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            archivedAt: .now
        )

        try repo.save(active)
        try repo.save(archived)

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.landscapePoints[3].chargeCount == 1)
        #expect(vm.landscapePoints[3].rawTotal == 100)
    }

    @Test("Annual item appears in landscape on its charge date")
    func annualItemAppearsInLandscape() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(title: "Annual", amount: 1200, billingCycle: .annual))

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.isLoaded)
        #expect(vm.landscapePoints[3].chargeCount == 1)
        #expect(vm.landscapePoints[3].rawTotal == 1200)
    }

    @Test("Zero-amount item still appears in landscape")
    func zeroAmountItemInLandscape() throws {
        let repo = try makeRepo()
        try repo.save(makeItem(title: "Free tier", amount: 0))

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.isLoaded)
        #expect(vm.landscapePoints[3].chargeCount == 1)
        #expect(vm.landscapePoints[3].rawTotal == 0)
    }

    // MARK: - Upcoming Window

    @Test("Items within 30-day window appear; items at day+31 do not")
    func upcomingWindowBoundary() throws {
        let repo = try makeRepo()

        let tomorrow = makeItem(title: "Tomorrow",
                                nextCharge: Calendar.current.date(byAdding: .day, value: 1, to: .now))
        let day7 = makeItem(title: "Day7",
                            nextCharge: Calendar.current.date(byAdding: .day, value: 7, to: .now))
        let day31 = makeItem(title: "Day31",
                             nextCharge: Calendar.current.date(byAdding: .day, value: 31, to: .now))

        try repo.save(tomorrow)
        try repo.save(day7)
        try repo.save(day31)

        let vm = makeViewModel(repo: repo)
        vm.load()

        let totalCharges = vm.landscapePoints.reduce(0) { $0 + $1.chargeCount }
        #expect(totalCharges == 2)
        #expect(vm.landscapePoints[1].chargeCount == 1)
        #expect(vm.landscapePoints[7].chargeCount == 1)
    }

    @Test("Past-due items don't crash ViewModel")
    func pastDueHandling() throws {
        let repo = try makeRepo()

        let overdue = makeItem(title: "Overdue",
                               nextCharge: Calendar.current.date(byAdding: .day, value: -2, to: .now))
        try repo.save(overdue)

        let vm = makeViewModel(repo: repo)
        vm.load()

        // Past items may or may not appear depending on repository logic
        // The key test: ViewModel doesn't crash on negative daysUntilNextCharge
        #expect(vm.isLoaded)
        #expect(!vm.hasError)
    }

    // MARK: - Upcoming Charges Section

    @Test("upcomingCharges returns at most 3 items, soonest first")
    func upcomingChargesLimitedAndSorted() throws {
        let repo = try makeRepo()
        let cal = Calendar.current

        for offset in [10, 2, 7, 1, 20] {
            try repo.save(makeItem(
                title: "Day\(offset)",
                nextCharge: cal.date(byAdding: .day, value: offset, to: .now)
            ))
        }

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.upcomingCharges.count == 3)
        #expect(vm.upcomingCharges.map(\.title) == ["Day1", "Day2", "Day7"])
        #expect(vm.screenState.upcomingCharges == vm.upcomingCharges)
    }

    @Test("upcomingCharges excludes cancelled, paused, and archived items even when due soonest")
    func upcomingChargesExcludesNonCountingStatuses() throws {
        let repo = try makeRepo()
        let cal = Calendar.current

        let cancelled = makeItem(title: "Cancelled", status: .cancelled,
                                  nextCharge: cal.date(byAdding: .day, value: 1, to: .now))
        let paused = makeItem(title: "Paused", status: .paused,
                               nextCharge: cal.date(byAdding: .day, value: 2, to: .now))
        let archived = RecurringItem(
            title: "Archived",
            amount: 199,
            currencyCode: "RUB",
            nextChargeDate: cal.date(byAdding: .day, value: 3, to: .now)!,
            status: .archived
        )
        let active = makeItem(title: "Active", status: .active,
                               nextCharge: cal.date(byAdding: .day, value: 5, to: .now))

        try repo.save(cancelled)
        try repo.save(paused)
        try repo.save(archived)
        try repo.save(active)

        let vm = makeViewModel(repo: repo)
        vm.load()

        // If filtering ran after the 3-item cap, the three excluded statuses
        // (due on days 1-3) would fill every slot and "Active" (day 5) would
        // never surface. Filtering must happen before the cap.
        #expect(vm.upcomingCharges.count == 1)
        #expect(vm.upcomingCharges.first?.title == "Active")
    }

    @Test("upcomingCharges includes a trial item that has an upcoming charge date")
    func upcomingChargesIncludesTrialWithChargeDate() throws {
        let repo = try makeRepo()
        let cal = Calendar.current

        let trial = makeItem(
            title: "Trial Service", status: .trial,
            nextCharge: cal.date(byAdding: .day, value: 3, to: .now),
            trialEndDate: cal.date(byAdding: .day, value: 3, to: .now)
        )
        try repo.save(trial)

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.upcomingCharges.contains { $0.title == "Trial Service" })
    }

    @Test("upcomingCharges is empty when every item is cancelled, paused, or archived")
    func upcomingChargesEmptyWhenNothingCounts() throws {
        let repo = try makeRepo()
        let cal = Calendar.current

        try repo.save(makeItem(title: "Cancelled", status: .cancelled,
                                nextCharge: cal.date(byAdding: .day, value: 1, to: .now)))
        try repo.save(makeItem(title: "Paused", status: .paused,
                                nextCharge: cal.date(byAdding: .day, value: 2, to: .now)))

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(vm.upcomingCharges.isEmpty)
        #expect(vm.isLoaded)
        #expect(!vm.hasError)
    }

    // MARK: - Insights / Active Trials

    @Test("Trial ending within 14 days appears in insights")
    func trialInsightAppearsForEndingSoonTrials() throws {
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
        vm.load()

        let trialInsight = vm.insights.first(where: { $0.id == .trial })
        #expect(trialInsight != nil)
        // Earliest-ending trial (T2, day+2) should be the one shown
        #expect(trialInsight?.value.contains("T2") == true)
    }

    @Test("Expired trial excluded — only active trial appears in insights")
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
        let regularActive = makeItem(title: "Regular", status: .active)

        try repo.save(activeTrial)
        try repo.save(expiredTrial)
        try repo.save(regularActive)

        let vm = makeViewModel(repo: repo)
        vm.load()

        let trialInsight = vm.insights.first(where: { $0.id == .trial })
        #expect(trialInsight != nil)
        #expect(trialInsight?.value.contains("Active Trial") == true)
    }

    @Test("Trial with nil trialEndDate does not produce trial insight")
    func trialWithNilEndDate() throws {
        let repo = try makeRepo()

        let brokenTrial = makeItem(title: "Broken", status: .trial, trialEndDate: nil)
        try repo.save(brokenTrial)

        let vm = makeViewModel(repo: repo)
        vm.load()

        #expect(!vm.insights.contains(where: { $0.id == .trial }))
    }

    // MARK: - Load Idempotency

    @Test("Multiple loads don't duplicate landscape data")
    func multipleLoads() throws {
        let repo = try makeRepo()
        let item = makeItem(title: "Single", amount: 100)
        try repo.save(item)

        let vm = makeViewModel(repo: repo)
        vm.load()
        vm.load()
        vm.load()

        #expect(vm.landscapePoints.count == 30)
        #expect(vm.landscapePoints[3].chargeCount == 1)
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
        vm.load()

        #expect(vm.isLoaded)
        #expect(!vm.hasError)
        #expect(vm.landscapePoints.reduce(0) { $0 + $1.chargeCount } == 3)
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
        vm.load()

        #expect(vm.isLoaded)
        #expect(vm.landscapePoints.count == 30)
        #expect(vm.landscapePoints.reduce(0) { $0 + $1.chargeCount } == 100)
    }

    // MARK: - All Statuses Survive Load

    @Test("Every ItemStatus survives through ViewModel load without crashing")
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
        vm.load()

        #expect(vm.isLoaded)
        #expect(!vm.hasError)
        // archived + cancelled + paused are filtered from fetchActive
        // but fetchUpcoming only filters archivedAt — chargeCount may be higher
        #expect(vm.landscapePoints.count == 30)
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
        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items)
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

        let items = try repo.fetchActive()
        let summary = GetDashboardSummary().execute(items: items)
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
