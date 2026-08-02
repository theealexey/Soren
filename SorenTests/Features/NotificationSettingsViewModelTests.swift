import Foundation
import Testing
@testable import Soren

@MainActor
private final class NotificationPermissionManagerStub: NotificationPermissionManaging {
    var status: NotificationAuthorizationStatus
    var requestOutcome: NotificationPermissionRequestOutcome
    private(set) var statusReadCount = 0
    private(set) var requestCount = 0
    private var requestStartedGate: NotificationTestGate?
    private var requestReleaseGate: NotificationTestGate?

    init(
        status: NotificationAuthorizationStatus,
        requestOutcome: NotificationPermissionRequestOutcome
    ) {
        self.status = status
        self.requestOutcome = requestOutcome
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        statusReadCount += 1
        return status
    }

    func requestAuthorizationFromSettings() async -> NotificationPermissionRequestOutcome {
        requestCount += 1
        let startedGate = requestStartedGate
        let releaseGate = requestReleaseGate
        requestStartedGate = nil
        requestReleaseGate = nil
        startedGate?.signal()
        if let releaseGate {
            await releaseGate.wait()
        }
        if case .completed(let status, _) = requestOutcome {
            self.status = status
        }
        return requestOutcome
    }

    func suspendNextRequest(started: NotificationTestGate, release: NotificationTestGate) {
        requestStartedGate = started
        requestReleaseGate = release
    }
}

@MainActor
private final class ApplicationSettingsOpenerStub: ApplicationSettingsOpening {
    var result: ApplicationSettingsOpenResult
    private(set) var callCount = 0

    init(result: ApplicationSettingsOpenResult) {
        self.result = result
    }

    func openApplicationSettings() async -> ApplicationSettingsOpenResult {
        callCount += 1
        return result
    }
}

@Suite("Settings notification authorization")
@MainActor
struct NotificationSettingsViewModelTests {
    private func repository() throws -> (UserPreferencesRepository, UserDefaults, String) {
        let suiteName = "NotificationSettingsViewModelTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (UserPreferencesRepository(defaults: defaults), defaults, suiteName)
    }

    @Test("status loading maps every system authorization state without prompting")
    func loadsEachAuthorizationState() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let manager = NotificationPermissionManagerStub(
            status: .notDetermined,
            requestOutcome: .requestFailed(status: .notDetermined)
        )
        let viewModel = SettingsViewModel(repository: fixture.0, permissionManager: manager)

        for status in [
            NotificationAuthorizationStatus.notDetermined,
            .authorized,
            .provisional,
            .ephemeral,
            .denied,
            .unknown
        ] {
            manager.status = status
            await viewModel.loadNotificationAuthorizationStatus()
            #expect(viewModel.notificationAuthorizationStatus == status)
        }

        #expect(manager.requestCount == 0)
    }

    @Test("enable action awaits the explicit permission outcome")
    func enableActionUsesOnlyPermissionManager() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let report = NotificationReconciliationReport(
            desiredCount: 1,
            removedPendingCount: 0,
            removedDeliveredCount: 0,
            addedCount: 1,
            authorizationStatus: .authorized,
            addFailures: [],
            planningFailures: []
        )
        let manager = NotificationPermissionManagerStub(
            status: .notDetermined,
            requestOutcome: .completed(status: .authorized, refresh: .reconciled(report))
        )
        let viewModel = SettingsViewModel(repository: fixture.0, permissionManager: manager)

        await viewModel.loadNotificationAuthorizationStatus()
        await viewModel.performNotificationPrimaryAction()

        #expect(manager.requestCount == 1)
        #expect(viewModel.notificationAuthorizationStatus == .authorized)
        #expect(viewModel.notificationError == nil)
        #expect(!viewModel.isNotificationActionInFlight)
    }

    @Test("denied state surfaces a Settings opening failure without changing preferences")
    func deniedStatePreservesSettingsOnOpenFailure() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let manager = NotificationPermissionManagerStub(
            status: .denied,
            requestOutcome: .requestFailed(status: .denied)
        )
        let opener = ApplicationSettingsOpenerStub(result: .failed)
        let viewModel = SettingsViewModel(
            repository: fixture.0,
            permissionManager: manager,
            settingsOpener: opener
        )
        let initialCurrency = viewModel.defaultCurrencyCode

        await viewModel.loadNotificationAuthorizationStatus()
        await viewModel.performNotificationPrimaryAction()

        #expect(opener.callCount == 1)
        #expect(viewModel.notificationError == .settingsOpenFailed)
        #expect(viewModel.defaultCurrencyCode == initialCurrency)
        #expect(manager.requestCount == 0)
    }

    @Test("foreground authorization update is prompt-free and preserves unrelated Settings state")
    func foregroundUpdateIsPromptFree() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let manager = NotificationPermissionManagerStub(
            status: .notDetermined,
            requestOutcome: .requestFailed(status: .notDetermined)
        )
        let viewModel = SettingsViewModel(repository: fixture.0, permissionManager: manager)
        let initialReminder = viewModel.defaultChargeReminder

        viewModel.applyForegroundAuthorizationStatus(.denied)

        #expect(viewModel.notificationAuthorizationStatus == .denied)
        #expect(viewModel.defaultChargeReminder == initialReminder)
        #expect(manager.requestCount == 0)
    }

    @Test("permission grant keeps authorization and surfaces a typed reconciliation warning")
    func permissionGrantKeepsAuthorizedStateAndSurfacesReconciliationWarning() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let report = NotificationReconciliationReport(
            desiredCount: 2,
            removedPendingCount: 0,
            removedDeliveredCount: 0,
            addedCount: 1,
            authorizationStatus: .authorized,
            addFailures: [.addFailed(identifier: "soren.v2.charge.item.20260812.3")],
            planningFailures: []
        )
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.authorized)
        let refresh = NotificationReconciliationSpy()
        refresh.outcome = .reconciled(report)
        let manager = NotificationPermissionCoordinator(center: center, refreshCoordinator: refresh)
        let viewModel = SettingsViewModel(repository: fixture.0, permissionManager: manager)
        let initialReminder = viewModel.defaultChargeReminder

        await viewModel.loadNotificationAuthorizationStatus()
        await viewModel.performNotificationPrimaryAction()

        #expect(viewModel.notificationAuthorizationStatus == .authorized)
        #expect(viewModel.notificationWarning == .addFailures)
        #expect(viewModel.notificationError == nil)
        #expect(viewModel.defaultChargeReminder == initialReminder)
    }

    @Test("explicit permission action exposes an in-flight presentation state")
    func explicitPermissionActionExposesInFlightPresentationState() async throws {
        let fixture = try repository()
        defer { fixture.1.removePersistentDomain(forName: fixture.2) }
        let manager = NotificationPermissionManagerStub(
            status: .notDetermined,
            requestOutcome: .completed(status: .authorized, refresh: nil)
        )
        let viewModel = SettingsViewModel(repository: fixture.0, permissionManager: manager)
        let started = NotificationTestGate()
        let release = NotificationTestGate()
        manager.suspendNextRequest(started: started, release: release)

        await viewModel.loadNotificationAuthorizationStatus()
        let action = Task { @MainActor in
            await viewModel.performNotificationPrimaryAction()
        }
        await started.wait()

        #expect(viewModel.isNotificationActionInFlight)
        #expect(viewModel.notificationPrimaryActionTitle != nil)

        release.signal()
        await action.value

        #expect(!viewModel.isNotificationActionInFlight)
    }
}
