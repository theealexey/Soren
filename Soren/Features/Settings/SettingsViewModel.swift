import Foundation

// MARK: - Settings View Model

/// Drives the Settings screen.
/// Loads and auto-saves user preferences to UserDefaults.
/// Note: appearanceMode is owned by AppState, not this ViewModel.
@MainActor @Observable
final class SettingsViewModel {

    enum NotificationError: Equatable {
        case permissionRequestFailed
        case settingsOpenFailed
    }

    enum NotificationWarning: Equatable {
        case planningFailures
        case addFailures
        case planningAndAddFailures
        case refreshFailed
    }

    // MARK: - Bindable State

    var defaultCurrencyCode: String {
        didSet { save() }
    }

    var pricingMarket: PricingMarket {
        didSet { save() }
    }

    var defaultChargeReminder: ChargeReminderOption {
        didSet { debouncedSave() }
    }

    private(set) var notificationAuthorizationStatus: NotificationAuthorizationStatus = .unknown
    private(set) var isNotificationStatusLoading = false
    private(set) var isNotificationActionInFlight = false
    private(set) var notificationError: NotificationError?
    private(set) var notificationWarning: NotificationWarning?

    // MARK: - Dependencies

    private let repository: UserPreferencesRepository
    private let permissionManager: (any NotificationPermissionManaging)?
    private let settingsOpener: (any ApplicationSettingsOpening)?

    /// Cancellable debounce task — coalesces rapid changes into a single UserDefaults write.
    private var saveTask: Task<Void, Never>?

    // MARK: - Init

    init(
        repository: UserPreferencesRepository = UserPreferencesRepository(),
        permissionManager: (any NotificationPermissionManaging)? = nil,
        settingsOpener: (any ApplicationSettingsOpening)? = nil
    ) {
        self.repository = repository
        self.permissionManager = permissionManager
        self.settingsOpener = settingsOpener
        let prefs = repository.load()
        self.defaultCurrencyCode  = prefs.defaultCurrencyCode
        self.pricingMarket = prefs.pricingMarket
        self.defaultChargeReminder = prefs.defaultChargeReminder
    }

    var notificationStatusText: String {
        switch notificationAuthorizationStatus {
        case .notDetermined: String(localized: "Уведомления не включены")
        case .denied: String(localized: "Отключены в настройках iOS")
        case .authorized: String(localized: "Включены")
        case .provisional: String(localized: "Включены тихо")
        case .ephemeral: String(localized: "Временно включены")
        case .unknown: String(localized: "Статус недоступен")
        }
    }

    var notificationPrimaryActionTitle: String? {
        switch notificationAuthorizationStatus {
        case .notDetermined: String(localized: "Включить уведомления")
        case .denied, .provisional, .ephemeral: String(localized: "Открыть настройки iOS")
        case .unknown: String(localized: "Повторить")
        case .authorized: nil
        }
    }

    var notificationErrorText: String? {
        switch notificationError {
        case .permissionRequestFailed:
            String(localized: "Не удалось запросить разрешение. Попробуйте ещё раз.")
        case .settingsOpenFailed:
            String(localized: "Не удалось открыть настройки iOS. Попробуйте ещё раз.")
        case nil:
            nil
        }
    }

    var notificationWarningText: String? {
        switch notificationWarning {
        case .planningFailures, .addFailures, .planningAndAddFailures:
            String(localized: "Уведомления включены, но некоторые напоминания не удалось запланировать.")
        case .refreshFailed:
            String(localized: "Уведомления включены, но не удалось обновить напоминания.")
        case nil:
            nil
        }
    }

    func loadNotificationAuthorizationStatus() async {
        guard let permissionManager else { return }
        guard !isNotificationStatusLoading, !isNotificationActionInFlight else { return }
        isNotificationStatusLoading = true
        notificationError = nil
        notificationAuthorizationStatus = await permissionManager.currentAuthorizationStatus()
        isNotificationStatusLoading = false
    }

    func applyForegroundAuthorizationStatus(_ status: NotificationAuthorizationStatus) {
        guard !isNotificationActionInFlight else { return }
        isNotificationStatusLoading = false
        notificationError = nil
        notificationAuthorizationStatus = status
    }

    func performNotificationPrimaryAction() async {
        guard !isNotificationActionInFlight else { return }
        isNotificationActionInFlight = true
        notificationError = nil
        defer { isNotificationActionInFlight = false }

        switch notificationAuthorizationStatus {
        case .notDetermined:
            guard let permissionManager else { return }
            notificationWarning = nil
            let outcome = await permissionManager.requestAuthorizationFromSettings()
            switch outcome {
            case .completed(let status, let refresh):
                notificationAuthorizationStatus = status
                notificationWarning = warning(from: refresh)
            case .requestFailed(let status):
                notificationAuthorizationStatus = status
                notificationError = .permissionRequestFailed
            }
        case .denied, .provisional, .ephemeral:
            guard let settingsOpener else { return }
            if await settingsOpener.openApplicationSettings() == .failed {
                notificationError = .settingsOpenFailed
            }
        case .unknown:
            guard let permissionManager else { return }
            isNotificationStatusLoading = true
            notificationAuthorizationStatus = await permissionManager.currentAuthorizationStatus()
            isNotificationStatusLoading = false
        case .authorized:
            break
        }
    }

    private func warning(from refresh: NotificationRefreshOutcome?) -> NotificationWarning? {
        guard let refresh else { return nil }
        switch refresh {
        case .reconciled(let report):
            return switch (!report.addFailures.isEmpty, !report.planningFailures.isEmpty) {
            case (true, true): .planningAndAddFailures
            case (true, false): .addFailures
            case (false, true): .planningFailures
            case (false, false): nil
            }
        case .repositoryFetchFailed:
            return .refreshFailed
        case .superseded:
            return nil
        }
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
            defaultCurrencyCode:   defaultCurrencyCode,
            pricingMarket:          pricingMarket,
            defaultChargeReminder: defaultChargeReminder,
            chargeAlertDays:       current.chargeAlertDays,
            trialAlertDays:        current.trialAlertDays
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

    static var supportedPricingMarkets: [PricingMarket] {
        ["US", "RU"].compactMap { try? PricingMarket(countryCode: $0) }
    }
}
