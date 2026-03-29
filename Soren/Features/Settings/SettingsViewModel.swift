import Foundation
import SwiftUI

// MARK: - Settings View Model

/// Drives the Settings screen.
/// Loads and auto-saves user preferences to UserDefaults.
@MainActor @Observable
final class SettingsViewModel {

    // MARK: - Bindable State

    var defaultCurrencyCode: String {
        didSet { save() }
    }

    var chargeAlertDays: Int {
        didSet { save() }
    }

    var trialAlertDays: Int {
        didSet { save() }
    }

    var appearanceMode: AppearanceMode {
        didSet { save() }
    }

    // MARK: - Dependencies

    private let repository: UserPreferencesRepository

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
        switch appearanceMode {
        case .system: nil
        case .light:  .light
        case .dark:   .dark
        }
    }

    // MARK: - Supported Currencies

    static let supportedCurrencies = SupportedCurrency.codes
}
