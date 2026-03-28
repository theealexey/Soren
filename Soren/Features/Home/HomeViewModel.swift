import SwiftUI

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
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getDashboardSummary: GetDashboardSummary
    private let getUpcomingCharges: GetUpcomingCharges
    private let getActiveTrials: GetActiveTrials
    private let preferences: UserPreferencesRepository

    // MARK: - Init

    init(
        getDashboardSummary: GetDashboardSummary,
        getUpcomingCharges: GetUpcomingCharges,
        getActiveTrials: GetActiveTrials,
        preferences: UserPreferencesRepository = UserPreferencesRepository()
    ) {
        self.getDashboardSummary = getDashboardSummary
        self.getUpcomingCharges = getUpcomingCharges
        self.getActiveTrials = getActiveTrials
        self.preferences = preferences
    }

    /// Convenience init from RepositoryContainer.
    init(repositories: RepositoryContainer, preferences: UserPreferencesRepository = UserPreferencesRepository()) {
        let repo = repositories.recurringItems
        self.getDashboardSummary = GetDashboardSummary(repository: repo)
        self.getUpcomingCharges = GetUpcomingCharges(repository: repo)
        self.getActiveTrials = GetActiveTrials(repository: repo)
        self.preferences = preferences
    }

    // MARK: - Actions

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        error = nil
        do {
            defaultCurrency = preferences.load().defaultCurrencyCode
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

    /// Determines trial urgency severity for insight cards.
    static func trialSeverity(for item: RecurringItem) -> InsightCard.Severity {
        guard let days = item.daysUntilTrialEnd else { return .info }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .info
    }

    /// Russian pluralization for "пробный период" count label.
    static func pluralTrial(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "пробный" }
        return "пробных"
    }
}

// MARK: - Insights

extension HomeViewModel {

    struct InsightData {
        let icon: String
        let title: String
        let subtitle: String?
        let severity: InsightCard.Severity
    }

    var insights: [InsightData] {
        var result: [InsightData] = []

        let overdueCount = upcomingCharges.filter { $0.daysUntilNextCharge < 0 }.count
        if overdueCount > 0 {
            result.append(InsightData(
                icon: "exclamationmark.triangle.fill",
                title: "\(overdueCount) просроченных списаний",
                subtitle: "Проверьте способы оплаты",
                severity: .critical
            ))
        }

        let weekTotal = upcomingCharges.reduce(Decimal.zero) { $0 + $1.amount }
        if weekTotal > 0 && upcomingCharges.count >= 2 {
            result.append(InsightData(
                icon: "calendar.badge.clock",
                title: "\(upcomingCharges.count) списаний на этой неделе",
                subtitle: nil,
                severity: .info
            ))
        }

        let failedCount = upcomingCharges.filter { $0.status == .failed }.count
        if failedCount > 0 {
            result.append(InsightData(
                icon: "creditcard.trianglebadge.exclamationmark",
                title: "\(failedCount) неудачных платежей",
                subtitle: "Требуется внимание",
                severity: .critical
            ))
        }

        return result
    }
}
