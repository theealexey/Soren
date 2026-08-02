import Foundation
import Testing
@testable import Soren

@Suite("Notification reconciliation observation")
@MainActor
struct NotificationReconciliationObservationTests {
    private func report(
        authorization: NotificationAuthorizationStatus = .authorized,
        addFailures: [NotificationReconciliationFailure] = [],
        planningFailures: [NotificationPlanningFailure] = []
    ) -> NotificationReconciliationReport {
        NotificationReconciliationReport(
            desiredCount: 3,
            removedPendingCount: 2,
            removedDeliveredCount: 1,
            addedCount: 2,
            authorizationStatus: authorization,
            addFailures: addFailures,
            planningFailures: planningFailures
        )
    }

    @Test("newest completed reconciliation replaces the previous non-sensitive record")
    func latestRecordReplacesPreviousRecord() {
        let observation = NotificationReconciliationObservation()
        observation.record(
            outcome: .reconciled(report()),
            source: .create,
            startedAt: .distantPast,
            completedAt: .distantFuture
        )
        observation.record(
            outcome: .reconciled(report(authorization: .provisional)),
            source: .permissionGrant,
            startedAt: .distantFuture,
            completedAt: .distantFuture
        )

        #expect(observation.latestRecord?.source == .permissionGrant)
        #expect(observation.latestRecord?.desiredCount == 3)
        #expect(observation.latestRecord?.removedPendingCount == 2)
        #expect(observation.latestRecord?.removedDeliveredCount == 1)
        #expect(observation.latestRecord?.authorizationStatus == .provisional)
        #expect(observation.revision == 2)
    }

    @Test("observation maps safe failure categories")
    func mapsFailureCategories() {
        let observation = NotificationReconciliationObservation()
        observation.record(
            outcome: .reconciled(report(addFailures: [.addFailed(identifier: "soren.v2.charge.id.20260812.3")])),
            source: .update,
            startedAt: .distantPast,
            completedAt: .distantFuture
        )

        #expect(observation.latestRecord?.failureCategory == .add)
        #expect(observation.latestRecord?.failedAddCount == 1)
        #expect(observation.latestRecord?.planningFailureCount == 0)
    }
}
