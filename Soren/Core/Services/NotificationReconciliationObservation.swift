import Foundation

enum NotificationReconciliationSource: String, Sendable, Equatable {
    case foreground
    case create
    case update
    case delete
    case permissionGrant
    case other
}

struct NotificationReconciliationRecord: Sendable, Equatable {
    let startedAt: Date
    let completedAt: Date
    let source: NotificationReconciliationSource
    let desiredCount: Int
    let removedPendingCount: Int
    let removedDeliveredCount: Int
    let addedCount: Int
    let failedAddCount: Int
    let planningFailureCount: Int
    let authorizationStatus: NotificationAuthorizationStatus
    let failureCategory: NotificationReconciliationFailureCategory?
}

enum NotificationReconciliationFailureCategory: Sendable, Equatable {
    case add
    case planning
    case planningAndAdd
    case repository
}

/// Shared, in-memory observation of non-sensitive notification operations.
/// It lets Settings refresh after foreground and supplies DEBUG diagnostics
/// without participating in scheduling correctness.
@MainActor @Observable
final class NotificationReconciliationObservation {
    private(set) var authorizationStatus: NotificationAuthorizationStatus = .unknown
    private(set) var latestRecord: NotificationReconciliationRecord?
    private(set) var revision = 0

    func record(
        outcome: NotificationRefreshOutcome,
        source: NotificationReconciliationSource,
        startedAt: Date,
        completedAt: Date
    ) {
        switch outcome {
        case .reconciled(let report):
            authorizationStatus = report.authorizationStatus
            let category: NotificationReconciliationFailureCategory?
            switch (!report.addFailures.isEmpty, !report.planningFailures.isEmpty) {
            case (true, true): category = .planningAndAdd
            case (true, false): category = .add
            case (false, true): category = .planning
            case (false, false): category = nil
            }
            latestRecord = NotificationReconciliationRecord(
                startedAt: startedAt,
                completedAt: completedAt,
                source: source,
                desiredCount: report.desiredCount,
                removedPendingCount: report.removedPendingCount,
                removedDeliveredCount: report.removedDeliveredCount,
                addedCount: report.addedCount,
                failedAddCount: report.addFailures.count,
                planningFailureCount: report.planningFailures.count,
                authorizationStatus: report.authorizationStatus,
                failureCategory: category
            )
        case .repositoryFetchFailed:
            latestRecord = NotificationReconciliationRecord(
                startedAt: startedAt,
                completedAt: completedAt,
                source: source,
                desiredCount: 0,
                removedPendingCount: 0,
                removedDeliveredCount: 0,
                addedCount: 0,
                failedAddCount: 0,
                planningFailureCount: 0,
                authorizationStatus: authorizationStatus,
                failureCategory: .repository
            )
        case .superseded:
            break
        }
        revision += 1
    }

    func updateAuthorizationStatus(_ status: NotificationAuthorizationStatus) {
        authorizationStatus = status
        revision += 1
    }
}
