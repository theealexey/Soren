import Foundation

enum NotificationReconciliationFailure: Sendable, Equatable {
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
    let capacityOmittedIdentifiers: [String]
    let deliveredDecisionSuppressedIdentifiers: [String]
    let missingPendingIdentifiers: [String]
    let pendingCountAfterReconciliation: Int?
    let pendingBudgetExceededCount: Int

    /// Scheduling/retention problems, never a statement about actual delivery.
    var hasSchedulingIssues: Bool {
        !addFailures.isEmpty || !planningFailures.isEmpty || !capacityOmittedIdentifiers.isEmpty ||
        !missingPendingIdentifiers.isEmpty || pendingBudgetExceededCount > 0 ||
        (desiredCount > deliveredDecisionSuppressedIdentifiers.count && !authorizationStatus.permitsScheduling)
    }

    init(
        desiredCount: Int, removedPendingCount: Int, removedDeliveredCount: Int, addedCount: Int,
        authorizationStatus: NotificationAuthorizationStatus,
        addFailures: [NotificationReconciliationFailure], planningFailures: [NotificationPlanningFailure],
        capacityOmittedIdentifiers: [String] = [], deliveredDecisionSuppressedIdentifiers: [String] = [],
        missingPendingIdentifiers: [String] = [], pendingCountAfterReconciliation: Int? = nil,
        pendingBudgetExceededCount: Int = 0
    ) {
        self.desiredCount = desiredCount
        self.removedPendingCount = removedPendingCount
        self.removedDeliveredCount = removedDeliveredCount
        self.addedCount = addedCount
        self.authorizationStatus = authorizationStatus
        self.addFailures = addFailures
        self.planningFailures = planningFailures
        self.capacityOmittedIdentifiers = capacityOmittedIdentifiers
        self.deliveredDecisionSuppressedIdentifiers = deliveredDecisionSuppressedIdentifiers
        self.missingPendingIdentifiers = missingPendingIdentifiers
        self.pendingCountAfterReconciliation = pendingCountAfterReconciliation
        self.pendingBudgetExceededCount = pendingBudgetExceededCount
    }
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
    // Conservative product budget; not an OS retention guarantee.
    private let pendingBudget = 60

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
        let status = await center.authorizationStatus()
        var failures: [NotificationReconciliationFailure] = []

        let pending = await center.pendingRequestIdentifiers()
        let delivered = await center.deliveredNotificationIdentifiers()
        let ownedPending = pending.filter(isSorenOwned)
        let ownedDelivered = delivered.filter { isSorenOwned($0) && !$0.hasPrefix("soren.v2.renewalDecision.") }
        let deliveredIDs = Set(delivered)
        let suppressed = Set(plan.requests.filter {
            $0.kind == .renewalDecision && deliveredIDs.contains($0.id)
        }.map(\.id))
        let availableSlots = max(0, pendingBudget - pending.filter { !isSorenOwned($0) }.count)
        var seen = Set<String>()
        let candidates = plan.requests.sorted(by: precedes).filter {
            !suppressed.contains($0.id) && seen.insert($0.id).inserted
        }
        let selected = Array(candidates.prefix(availableSlots))
        let omitted = candidates.dropFirst(selected.count).map(\.id)

        if !ownedPending.isEmpty {
            center.removePending(identifiers: ownedPending)
        }
        if !ownedDelivered.isEmpty {
            center.removeDelivered(identifiers: ownedDelivered)
        }

        var addedCount = 0
        if status.permitsScheduling {
            for request in selected {
                do {
                    try await center.add(request)
                    addedCount += 1
                } catch {
                    failures.append(.addFailed(identifier: request.id))
                }
            }
        }

        let retained = Set(await center.pendingRequestIdentifiers())
        let missing = status.permitsScheduling ? selected.map(\.id).filter { !retained.contains($0) } : []
        return NotificationReconciliationReport(
            desiredCount: plan.requests.count,
            removedPendingCount: ownedPending.count,
            removedDeliveredCount: ownedDelivered.count,
            addedCount: addedCount,
            authorizationStatus: status,
            addFailures: failures,
            planningFailures: plan.failures,
            capacityOmittedIdentifiers: omitted,
            deliveredDecisionSuppressedIdentifiers: suppressed.sorted(),
            missingPendingIdentifiers: missing,
            pendingCountAfterReconciliation: retained.count,
            pendingBudgetExceededCount: max(0, retained.count - pendingBudget)
        )
    }

    private func precedes(_ lhs: PlannedNotificationRequest, _ rhs: PlannedNotificationRequest) -> Bool {
        if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
        let left = priority(lhs.kind), right = priority(rhs.kind)
        if left != right { return left < right }
        return lhs.id < rhs.id
    }

    private func priority(_ kind: NotificationRequestKind) -> Int {
        switch kind {
        case .trial: 0
        case .charge: 1
        case .renewalDecision: 2
        }
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
