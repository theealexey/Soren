import Foundation
@testable import Soren

@MainActor
final class NotificationReconciliationSpy: NotificationStateReconciling {
    private(set) var callCount = 0
    var outcome = NotificationRefreshOutcome.reconciled(
        NotificationReconciliationReport(
            desiredCount: 0,
            removedPendingCount: 0,
            removedDeliveredCount: 0,
            addedCount: 0,
            authorizationStatus: .authorized,
            addFailures: [],
            planningFailures: []
        )
    )

    func reconcileCurrentState() async -> NotificationRefreshOutcome {
        callCount += 1
        return outcome
    }
}

@MainActor
final class NotificationTestGate {
    private var wasSignaled = false
    private var waiter: CheckedContinuation<Void, Never>?

    func signal() {
        wasSignaled = true
        let continuation = waiter
        waiter = nil
        continuation?.resume()
    }

    func wait() async {
        guard !wasSignaled else { return }
        await withCheckedContinuation { continuation in
            waiter = continuation
        }
    }
}

@MainActor
final class FakeNotificationCenterClient: NotificationCenterClient {
    enum AddError: Error { case rejected }

    var status: NotificationAuthorizationStatus
    var authorizationResult: Result<NotificationAuthorizationStatus, Error>?
    var pending: Set<String>
    var delivered: Set<String>
    var rejectedIDs: Set<String> = []
    private(set) var added: [PlannedNotificationRequest] = []
    private(set) var removedPending: [String] = []
    private(set) var removedDelivered: [String] = []
    private var suspendsNextAdd = false
    private var didSuspendAdd = false
    private var addSuspendedContinuation: CheckedContinuation<Void, Never>?
    private var resumeAddContinuation: CheckedContinuation<Void, Never>?

    init(
        status: NotificationAuthorizationStatus = .authorized,
        pending: Set<String> = [],
        delivered: Set<String> = []
    ) {
        self.status = status
        self.pending = pending
        self.delivered = delivered
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus { status }

    func requestAuthorization() async throws -> NotificationAuthorizationStatus {
        if let authorizationResult {
            switch authorizationResult {
            case .success(let result):
                status = result
                return result
            case .failure(let error):
                throw error
            }
        }
        return status
    }

    func pendingRequestIdentifiers() async -> [String] { Array(pending).sorted() }
    func deliveredNotificationIdentifiers() async -> [String] { Array(delivered).sorted() }

    func add(_ request: PlannedNotificationRequest) async throws {
        if suspendsNextAdd {
            suspendsNextAdd = false
            didSuspendAdd = true

            let suspendedContinuation = addSuspendedContinuation
            addSuspendedContinuation = nil
            suspendedContinuation?.resume()

            await withCheckedContinuation { continuation in
                resumeAddContinuation = continuation
            }
        }

        if rejectedIDs.contains(request.id) { throw AddError.rejected }
        pending.insert(request.id)
        added.append(request)
    }

    func suspendNextAdd() {
        suspendsNextAdd = true
    }

    func waitUntilAddIsSuspended() async {
        guard !didSuspendAdd else { return }
        await withCheckedContinuation { continuation in
            addSuspendedContinuation = continuation
        }
    }

    func resumeSuspendedAdd() {
        let continuation = resumeAddContinuation
        resumeAddContinuation = nil
        continuation?.resume()
    }

    func removePending(identifiers: [String]) {
        removedPending.append(contentsOf: identifiers)
        pending.subtract(identifiers)
    }

    func removeDelivered(identifiers: [String]) {
        removedDelivered.append(contentsOf: identifiers)
        delivered.subtract(identifiers)
    }
}
