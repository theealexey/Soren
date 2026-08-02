import Foundation

// MARK: - Notification Refresh Coordinator

enum NotificationRefreshOutcome: Sendable, Equatable {
    case reconciled(NotificationReconciliationReport)
    case superseded
    case repositoryFetchFailed
}

@MainActor
protocol NotificationStateReconciling: AnyObject {
    func reconcileCurrentState(source: NotificationReconciliationSource) async -> NotificationRefreshOutcome
}

extension NotificationStateReconciling {
    func reconcileCurrentState() async -> NotificationRefreshOutcome {
        await reconcileCurrentState(source: .other)
    }
}

/// Loads authoritative persistence state and submits its complete desired plan
/// to the serialized reconciler. It owns app-lifecycle orchestration, not
/// UserNotifications details.
@MainActor
final class NotificationRefreshCoordinator: NotificationStateReconciling {

    // MARK: - Dependencies

    private let repository: any RecurringItemRepository
    private let planner: NotificationRequestPlanner
    private let reconciler: any NotificationReconciling
    private let observation: NotificationReconciliationObservation?
    private var refreshTask: Task<Void, Never>?
    private var latestRefreshRevision = 0

    // MARK: - Init

    init(
        repository: any RecurringItemRepository,
        planner: NotificationRequestPlanner = NotificationRequestPlanner(
            calendar: .current,
            locale: .current
        ),
        reconciler: any NotificationReconciling,
        observation: NotificationReconciliationObservation? = nil
    ) {
        self.repository = repository
        self.planner = planner
        self.reconciler = reconciler
        self.observation = observation
    }

    // MARK: - Activation

    func reconcileCurrentState(source: NotificationReconciliationSource = .other) async -> NotificationRefreshOutcome {
        let startedAt = Date.now
        latestRefreshRevision += 1
        let revision = latestRefreshRevision

        do {
            let items = try repository.fetchAll()
            guard revision == latestRefreshRevision else {
                return .superseded
            }
            let plan = planner.plan(items: items, now: .now)
            let outcome = NotificationRefreshOutcome.reconciled(await reconciler.reconcile(plan: plan))
            observation?.record(outcome: outcome, source: source, startedAt: startedAt, completedAt: .now)
            return outcome
        } catch {
            let outcome = NotificationRefreshOutcome.repositoryFetchFailed
            observation?.record(outcome: outcome, source: source, startedAt: startedAt, completedAt: .now)
            return outcome
        }
    }

    /// Called when the app scene transitions to `.active`. The task is owned by
    /// the lifecycle coordinator; reconciliation itself serializes and coalesces
    /// concurrent desired plans to guarantee the latest final state.
    func didBecomeActive() {
        refreshTask = Task { [weak self] in
            _ = await self?.reconcileCurrentState(source: .foreground)
        }
    }
}
