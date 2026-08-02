import Foundation

/// Settings-only permission orchestration. It keeps the system prompt out of
/// automatic reconciliation while preserving a complete refresh after a grant.
enum NotificationPermissionRequestOutcome: Sendable, Equatable {
    case completed(status: NotificationAuthorizationStatus, refresh: NotificationRefreshOutcome?)
    case requestFailed(status: NotificationAuthorizationStatus)
}

@MainActor
protocol NotificationPermissionManaging: AnyObject {
    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorizationFromSettings() async -> NotificationPermissionRequestOutcome
}

@MainActor
final class NotificationPermissionCoordinator: NotificationPermissionManaging {
    private let center: any NotificationCenterClient
    private let refreshCoordinator: any NotificationStateReconciling
    private let observation: NotificationReconciliationObservation?
    private var isRequesting = false
    private var waiters: [CheckedContinuation<NotificationPermissionRequestOutcome, Never>] = []

    init(
        center: any NotificationCenterClient,
        refreshCoordinator: any NotificationStateReconciling,
        observation: NotificationReconciliationObservation? = nil
    ) {
        self.center = center
        self.refreshCoordinator = refreshCoordinator
        self.observation = observation
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        await center.authorizationStatus()
    }

    func requestAuthorizationFromSettings() async -> NotificationPermissionRequestOutcome {
        if isRequesting {
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isRequesting = true
        let outcome = await requestAuthorizationOnce()
        isRequesting = false

        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume(returning: outcome) }
        return outcome
    }

    private func requestAuthorizationOnce() async -> NotificationPermissionRequestOutcome {
        let currentStatus = await center.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return await complete(status: currentStatus)
        }

        do {
            _ = try await center.requestAuthorization()
            return await complete(status: center.authorizationStatus())
        } catch {
            let status = await center.authorizationStatus()
            observation?.updateAuthorizationStatus(status)
            return .requestFailed(status: status)
        }
    }

    private func complete(status: NotificationAuthorizationStatus) async -> NotificationPermissionRequestOutcome {
        observation?.updateAuthorizationStatus(status)
        let refresh = status.permitsScheduling
            ? await refreshCoordinator.reconcileCurrentState(source: .permissionGrant)
            : nil
        return .completed(status: status, refresh: refresh)
    }
}
