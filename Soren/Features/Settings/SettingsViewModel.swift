import Foundation

// MARK: - Settings View Model

/// Drives the Settings screen.
/// Loads and auto-saves user preferences to UserDefaults.
/// Note: appearanceMode is owned by AppState, not this ViewModel.
@MainActor @Observable
final class SettingsViewModel {

    // MARK: - Bindable State

    var defaultCurrencyCode: String {
        didSet { debouncedSave() }
    }

    var defaultChargeReminder: ChargeReminderOption {
        didSet { debouncedSave() }
    }

    // MARK: - Dependencies

    private let repository: UserPreferencesRepository

    /// Cancellable debounce task — coalesces rapid changes into a single UserDefaults write.
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(repository: UserPreferencesRepository = UserPreferencesRepository()) {
        self.repository = repository
        let prefs = repository.load()
        self.defaultCurrencyCode  = prefs.defaultCurrencyCode
        self.defaultChargeReminder = prefs.defaultChargeReminder
    }

    // MARK: - Save

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        // Preserve the existing alert thresholds — they are consumed by the in-app
        // Alerts tab and are not configurable from Settings in v1.
        let current = repository.load()
        repository.save(UserPreferences(
            defaultCurrencyCode:  defaultCurrencyCode,
            defaultChargeReminder: defaultChargeReminder,
            chargeAlertDays:      current.chargeAlertDays,
            trialAlertDays:       current.trialAlertDays
        ))
    }

    // MARK: - App Info

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    // MARK: - Supported Currencies

    static let supportedCurrencies = SupportedCurrency.codes
}
