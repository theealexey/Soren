import Foundation

// MARK: - Alerts View Model

/// Drives the Alerts Center screen.
/// Groups alert-worthy items by urgency and severity.
@MainActor @Observable
final class AlertsViewModel {

    // MARK: - State

    private(set) var alerts: AlertsResult = AlertsResult(
        overdue: [], failed: [], dueToday: [], dueSoon: [], trialEnding: []
    )
    private(set) var error: Error?
    private(set) var isLoaded = false

    var hasError: Bool { error != nil }

    // MARK: - Dependencies

    private let getAlerts: GetAlerts
    private let preferences: UserPreferencesRepository

    // MARK: - Init

    init(repositories: RepositoryContainer, preferences: UserPreferencesRepository = UserPreferencesRepository()) {
        self.getAlerts = GetAlerts(repository: repositories.recurringItems)
        self.preferences = preferences
    }

    // MARK: - Actions

    func load() {
        error = nil
        do {
            let prefs = preferences.load()
            alerts = try getAlerts.execute(
                chargeAlertDays: prefs.chargeAlertDays,
                trialAlertDays: prefs.trialAlertDays
            )
            isLoaded = true
        } catch {
            self.error = error
        }
    }

    // MARK: - Computed

    var alertSections: [AlertSection] {
        var sections: [AlertSection] = []

        if !alerts.overdue.isEmpty {
            sections.append(AlertSection(
                title: "Просрочено",
                icon: "exclamationmark.triangle.fill",
                severity: .critical,
                items: alerts.overdue
            ))
        }

        if !alerts.failed.isEmpty {
            sections.append(AlertSection(
                title: "Ошибка оплаты",
                icon: "xmark.circle.fill",
                severity: .critical,
                items: alerts.failed
            ))
        }

        if !alerts.dueToday.isEmpty {
            sections.append(AlertSection(
                title: "Списание сегодня",
                icon: "exclamationmark.circle.fill",
                severity: .warning,
                items: alerts.dueToday
            ))
        }

        if !alerts.dueSoon.isEmpty {
            sections.append(AlertSection(
                title: "Скоро списание",
                icon: "clock.fill",
                severity: .warning,
                items: alerts.dueSoon
            ))
        }

        if !alerts.trialEnding.isEmpty {
            sections.append(AlertSection(
                title: "Пробный период заканчивается",
                icon: "clock.badge.exclamationmark",
                severity: .info,
                items: alerts.trialEnding
            ))
        }

        return sections
    }
}

// MARK: - Alert Section

struct AlertSection: Identifiable {
    let title: String
    let icon: String
    let severity: InsightCard.Severity
    let items: [RecurringItem]

    var id: String { title }
}
