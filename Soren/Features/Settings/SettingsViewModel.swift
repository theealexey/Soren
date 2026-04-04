import Foundation
import SwiftUI

// MARK: - Settings View Model

/// Drives the Settings screen.
/// Loads and auto-saves user preferences to UserDefaults.
@MainActor @Observable
final class SettingsViewModel {

    // MARK: - Bindable State

    var defaultCurrencyCode: String {
        didSet { debouncedSave() }
    }

    var chargeAlertDays: Int {
        didSet { debouncedSave() }
    }

    var trialAlertDays: Int {
        didSet { debouncedSave() }
    }

    var appearanceMode: AppearanceMode {
        didSet { debouncedSave() }
    }

    // MARK: - Dependencies

    private let repository: UserPreferencesRepository

    /// Cancellable debounce task — prevents a UserDefaults write on every stepper tick.
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(repository: UserPreferencesRepository = UserPreferencesRepository()) {
        self.repository = repository
        let prefs = repository.load()
        self.defaultCurrencyCode = prefs.defaultCurrencyCode
        self.chargeAlertDays = prefs.chargeAlertDays
        self.trialAlertDays = prefs.trialAlertDays
        self.appearanceMode = prefs.appearanceMode
    }

    // MARK: - Save

    /// Coalesces rapid changes (e.g., stepper taps) into a single UserDefaults write.
    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    private func save() {
        let prefs = UserPreferences(
            defaultCurrencyCode: defaultCurrencyCode,
            chargeAlertDays: chargeAlertDays,
            trialAlertDays: trialAlertDays,
            appearanceMode: appearanceMode
        )
        repository.save(prefs)
    }

    // MARK: - App Info

    var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    // MARK: - Color Scheme

    var preferredColorScheme: ColorScheme? {
        appearanceMode.colorScheme
    }

    // MARK: - Supported Currencies

    static let supportedCurrencies = SupportedCurrency.codes
}
