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

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
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
                title: String(localized: "Просрочено"),
                icon: "exclamationmark.triangle.fill",
                severity: .critical,
                items: alerts.overdue
            ))
        }

        if !alerts.failed.isEmpty {
            sections.append(AlertSection(
                title: String(localized: "Ошибка оплаты"),
                icon: "xmark.circle.fill",
                severity: .critical,
                items: alerts.failed
            ))
        }

        if !alerts.dueToday.isEmpty {
            sections.append(AlertSection(
                title: String(localized: "Списание сегодня"),
                icon: "exclamationmark.circle.fill",
                severity: .warning,
                items: alerts.dueToday
            ))
        }

        if !alerts.dueSoon.isEmpty {
            sections.append(AlertSection(
                title: String(localized: "Скоро списание"),
                icon: "clock.fill",
                severity: .warning,
                items: alerts.dueSoon
            ))
        }

        if !alerts.trialEnding.isEmpty {
            sections.append(AlertSection(
                title: String(localized: "Пробный период заканчивается"),
                icon: "clock.badge.exclamationmark",
                severity: .info,
                items: alerts.trialEnding
            ))
        }

        return sections
    }
    // MARK: - Formatters

    var criticalTitle: String {
        let count = alerts.criticalCount
        if count == 1 { return String(localized: "1 критическая проблема") }
        return String(localized: "\(count) критических проблем")
    }

    func alertCountTitle(_ count: Int) -> String {
        if count == 1 { return String(localized: "1 предупреждение") }
        return String(localized: "\(count) предупреждений")
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
