import Foundation

// MARK: - Home View Model

/// Drives the Home / Dashboard screen.
/// Loads financial summary, upcoming charges, and active trials
/// through dedicated Use Cases.
@MainActor @Observable
final class HomeViewModel {

    // MARK: - State

    private(set) var summary: DashboardSummary = .empty
    private(set) var upcomingCharges: [RecurringItem] = []
    private(set) var activeTrials: [RecurringItem] = []
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let getUpcomingCharges: GetUpcomingCharges
    private let getActiveTrials: GetActiveTrials

    // MARK: - Init

    init(
        getDashboardSummary: GetDashboardSummary,
        getUpcomingCharges: GetUpcomingCharges,
        getActiveTrials: GetActiveTrials
    ) {
        self.getDashboardSummary = getDashboardSummary
        self.getUpcomingCharges = getUpcomingCharges
        self.getActiveTrials = getActiveTrials
    }

    /// Convenience init from RepositoryContainer.
    init(repositories: RepositoryContainer) {
        let repo = repositories.recurringItems
        self.getDashboardSummary = GetDashboardSummary(repository: repo)
        self.getUpcomingCharges = GetUpcomingCharges(repository: repo)
        self.getActiveTrials = GetActiveTrials(repository: repo)
    }

    // MARK: - Actions

    func load() {
        error = nil
        do {
            summary = try getDashboardSummary.execute()
            upcomingCharges = try getUpcomingCharges.execute()
            activeTrials = try getActiveTrials.execute()
            isLoaded = true
        } catch {
            self.error = error
        }
    }
}

// MARK: - Display Helpers

extension HomeViewModel {

    /// Maps BillingCycle to the AmountLabel CycleLabel used in list rows.
    static func cycleLabel(for cycle: BillingCycle) -> AmountLabel.CycleLabel {
        switch cycle {
        case .weekly:       .weekly
        case .monthly:      .monthly
        case .annual:       .yearly
        case .quarterly:    .custom("кв")
        case .semiannual:   .custom("п/г")
        case .custom(let d): .custom("\(d)д")
        }
    }

    /// Determines the badge to show on an upcoming charge row.
    static func badge(for item: RecurringItem) -> SorenListRow.Badge? {
        if item.isActiveTrial { return .trial }
        switch item.status {
        case .failed:   return .failed
        case .paused:   return .paused
        case .dueSoon, .dueToday:
            return .dueSoon
        default:
            return item.billingCycle.isLongCycle ? .annual : nil
        }
    }

    /// Formatted subtitle for upcoming charge rows.
    static func chargeSubtitle(for item: RecurringItem) -> String {
        let days = item.daysUntilNextCharge
        if days == 0 { return "Списание сегодня" }
        if days == 1 { return "Списание завтра" }
        if days < 0 { return "Просрочено на \(abs(days)) дн." }
        return "Через \(days) дн."
    }

    /// Formatted subtitle for trial insight cards.
    static func trialSubtitle(for item: RecurringItem) -> String {
        guard let daysLeft = item.daysUntilTrialEnd else {
            return "Пробный период"
        }
        if daysLeft <= 0 { return "Пробный период заканчивается сегодня" }
        if daysLeft == 1 { return "Остался 1 день" }
        return "Осталось \(daysLeft) дн."
    }
}
