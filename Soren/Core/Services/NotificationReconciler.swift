import Foundation

enum NotificationReconciliationFailure: Sendable, Equatable {
    case authorizationRequestFailed
    case addFailed(identifier: String)
}

struct NotificationReconciliationReport: Sendable, Equatable {
    let desiredCount: Int
    let removedPendingCount: Int
    let removedDeliveredCount: Int
    let addedCount: Int
    let authorizationStatus: NotificationAuthorizationStatus
    let addFailures: [NotificationReconciliationFailure]
    let planningFailures: [NotificationPlanningFailure]
}

@MainActor
protocol NotificationReconciling: AnyObject {
    func reconcile(plan: NotificationRequestPlan) async -> NotificationReconciliationReport
}

/// Serializes mutations of Soren-owned notification state. New plans received
/// while a center call is suspended are coalesced; the final loop iteration
/// always reconciles the latest submitted desired state.
@MainActor
final class NotificationReconciler: NotificationReconciling {
    private let center: any NotificationCenterClient
    private var latestPlan: NotificationRequestPlan?
    private var isReconciling = false
    private var waiters: [CheckedContinuation<NotificationReconciliationReport, Never>] = []

    init(center: any NotificationCenterClient) {
        self.center = center
    }

    func reconcile(plan: NotificationRequestPlan) async -> NotificationReconciliationReport {
        latestPlan = plan
        if isReconciling {
            return await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        isReconciling = true
        let report = await drainLatestPlans()
        isReconciling = false

        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume(returning: report) }
        return report
    }

    private func drainLatestPlans() async -> NotificationReconciliationReport {
        var report = emptyReport
        while let plan = latestPlan {
            latestPlan = nil
            report = await reconcileOnce(plan)
        }
        return report
    }

    private func reconcileOnce(_ plan: NotificationRequestPlan) async -> NotificationReconciliationReport {
        var status = await center.authorizationStatus()
        var failures: [NotificationReconciliationFailure] = []

        if status == .notDetermined {
            do {
                status = try await center.requestAuthorization()
            } catch {
                failures.append(.authorizationRequestFailed)
                status = .unknown
            }
        }

        let pending = await center.pendingRequestIdentifiers()
        let delivered = await center.deliveredNotificationIdentifiers()
        let ownedPending = pending.filter(isSorenOwned)
        let ownedDelivered = delivered.filter(isSorenOwned)

        if !ownedPending.isEmpty {
            center.removePending(identifiers: ownedPending)
        }
        if !ownedDelivered.isEmpty {
            center.removeDelivered(identifiers: ownedDelivered)
        }

        var addedCount = 0
        if status.permitsScheduling {
            for request in plan.requests {
                do {
                    try await center.add(request)
                    addedCount += 1
                } catch {
                    failures.append(.addFailed(identifier: request.id))
                }
            }
        }

        return NotificationReconciliationReport(
            desiredCount: plan.requests.count,
            removedPendingCount: ownedPending.count,
            removedDeliveredCount: ownedDelivered.count,
            addedCount: addedCount,
            authorizationStatus: status,
            addFailures: failures,
            planningFailures: plan.failures
        )
    }

    private var emptyReport: NotificationReconciliationReport {
        NotificationReconciliationReport(
            desiredCount: 0,
            removedPendingCount: 0,
            removedDeliveredCount: 0,
            addedCount: 0,
            authorizationStatus: .unknown,
            addFailures: [],
            planningFailures: []
        )
    }

    private func isSorenOwned(_ identifier: String) -> Bool {
        identifier.hasPrefix("soren.")
    }
}
