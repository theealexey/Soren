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
    private let planner: () -> NotificationRequestPlanner
    private let reconciler: any NotificationReconciling
    private let observation: NotificationReconciliationObservation?
    private(set) var refreshTask: Task<Void, Never>?
    private var latestRefreshRevision = 0
    private(set) var lastRepositoryError: Error?
    private let now: () -> Date

    // MARK: - Init

    init(
        repository: any RecurringItemRepository,
        planner: NotificationRequestPlanner? = nil,
        reconciler: any NotificationReconciling,
        observation: NotificationReconciliationObservation? = nil,
        timeZone: @escaping () -> TimeZone = { .current },
        now: @escaping () -> Date = { .now }
    ) {
        self.repository = repository
        self.planner = {
            if let planner { return planner }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone()
            return NotificationRequestPlanner(calendar: calendar, locale: PresentationLocale.current)
        }
        self.reconciler = reconciler
        self.observation = observation
        self.now = now
    }

    // MARK: - Activation

    func reconcileCurrentState(source: NotificationReconciliationSource = .other) async -> NotificationRefreshOutcome {
        let startedAt = now()
        latestRefreshRevision += 1
        let revision = latestRefreshRevision

        do {
            let items = try repository.fetchAll()
            lastRepositoryError = nil
            guard revision == latestRefreshRevision else {
                return .superseded
            }
            let plan = planner().plan(items: items, now: now())
            let outcome = NotificationRefreshOutcome.reconciled(await reconciler.reconcile(plan: plan))
            observation?.record(outcome: outcome, source: source, startedAt: startedAt, completedAt: .now)
            return outcome
        } catch {
            lastRepositoryError = error
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
