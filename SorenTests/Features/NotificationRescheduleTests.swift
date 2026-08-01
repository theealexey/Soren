import Testing
import Foundation
@testable import Soren

@Suite("Notification reconciliation")
@MainActor
struct NotificationReconcilerTests {
    private func request(id: String = "soren.v2.charge.item.20260812.3") -> PlannedNotificationRequest {
        PlannedNotificationRequest(
            id: id,
            itemID: UUID(),
            kind: .charge,
            occurrenceDate: .distantFuture,
            occurrenceLocalDateKey: "20260812",
            reminderOffsetDays: 3,
            fireDate: .distantFuture,
            trigger: NotificationTriggerPlan(year: 2026, month: 8, day: 9, hour: 9, minute: 0, timeZoneIdentifier: "Europe/Moscow", repeats: false),
            title: "Expected charge: Spotify",
            body: "12 August 2026"
        )
    }

    @Test("reconciliation migrates v1, clears delivered owned requests and preserves unrelated IDs")
    func migrationAndOwnership() async {
        let center = FakeNotificationCenterClient(
            pending: ["soren.charge.old", "soren.trial.old", "other.feature"],
            delivered: ["soren.charge.old", "other.delivered"]
        )
        let reconciler = NotificationReconciler(center: center)
        let desired = request()
        let report = await reconciler.reconcile(plan: NotificationRequestPlan(requests: [desired], failures: []))
        #expect(report.removedPendingCount == 2)
        #expect(report.removedDeliveredCount == 1)
        #expect(center.pending == [desired.id, "other.feature"])
        #expect(center.delivered == ["other.delivered"])
    }

    @Test("same desired plan converges without duplicate pending identifiers")
    func idempotency() async {
        let center = FakeNotificationCenterClient()
        let reconciler = NotificationReconciler(center: center)
        let plan = NotificationRequestPlan(requests: [request()], failures: [])
        _ = await reconciler.reconcile(plan: plan)
        _ = await reconciler.reconcile(plan: plan)
        #expect(center.pending.count == 1)
        #expect(center.added.count == 2)
    }

    @Test("denied authorization cleans owned stale requests without adding desired requests")
    func deniedAuthorization() async {
        let center = FakeNotificationCenterClient(status: .denied, pending: ["soren.charge.old"])
        let reconciler = NotificationReconciler(center: center)
        let report = await reconciler.reconcile(plan: NotificationRequestPlan(requests: [request()], failures: []))
        #expect(report.authorizationStatus == .denied)
        #expect(report.addedCount == 0)
        #expect(center.pending.isEmpty)
    }

    @Test("independent add failures are retained in the typed report")
    func partialAddFailure() async {
        let first = request(id: "soren.v2.charge.one.20260812.3")
        let second = request(id: "soren.v2.trial.two.20260812.3")
        let center = FakeNotificationCenterClient()
        center.rejectedIDs = [first.id]
        let reconciler = NotificationReconciler(center: center)
        let report = await reconciler.reconcile(plan: NotificationRequestPlan(requests: [first, second], failures: []))
        #expect(report.addedCount == 1)
        #expect(report.addFailures == [.addFailed(identifier: first.id)])
        #expect(center.pending == [second.id])
    }

    @Test("legacy charge pending identifier is removed during v2 migration")
    func legacyChargePendingIsRemoved() async {
        let center = FakeNotificationCenterClient(pending: ["soren.charge.legacy"])
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [], failures: [])
        )
        #expect(report.removedPendingCount == 1)
        #expect(center.pending.isEmpty)
    }

    @Test("legacy trial delivered identifier is removed during v2 migration")
    func legacyTrialDeliveredIsRemoved() async {
        let center = FakeNotificationCenterClient(delivered: ["soren.trial.legacy"])
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [], failures: [])
        )
        #expect(report.removedDeliveredCount == 1)
        #expect(center.delivered.isEmpty)
    }

    @Test("unrelated pending identifier is preserved")
    func unrelatedPendingIsPreserved() async {
        let center = FakeNotificationCenterClient(pending: ["other.feature.pending"])
        _ = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [], failures: [])
        )
        #expect(center.pending == ["other.feature.pending"])
    }

    @Test("unrelated delivered identifier is preserved")
    func unrelatedDeliveredIsPreserved() async {
        let center = FakeNotificationCenterClient(delivered: ["other.feature.delivered"])
        _ = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [], failures: [])
        )
        #expect(center.delivered == ["other.feature.delivered"])
    }

    @Test("changed occurrence removes the prior desired request")
    func changedOccurrenceReplacesPriorRequest() async {
        let old = request(id: "soren.v2.charge.item.20260812.3")
        let new = request(id: "soren.v2.charge.item.20260815.3")
        let center = FakeNotificationCenterClient(pending: [old.id])
        _ = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [new], failures: [])
        )
        #expect(center.pending == [new.id])
        #expect(center.removedPending == [old.id])
    }

    @Test("changed offset removes the prior desired request")
    func changedOffsetReplacesPriorRequest() async {
        let old = request(id: "soren.v2.charge.item.20260812.3")
        let new = request(id: "soren.v2.charge.item.20260812.1")
        let center = FakeNotificationCenterClient(pending: [old.id])
        _ = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [new], failures: [])
        )
        #expect(center.pending == [new.id])
        #expect(center.removedPending == [old.id])
    }

    @Test("not-determined authorization granted adds desired requests")
    func authorizationGrantAddsRequests() async {
        let desired = request()
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.authorized)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [desired], failures: [])
        )
        #expect(report.authorizationStatus == .authorized)
        #expect(report.addedCount == 1)
        #expect(center.pending == [desired.id])
    }

    @Test("not-determined authorization denied returns an explicit denied result")
    func authorizationDenialIsExplicit() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.denied)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [request()], failures: [])
        )
        #expect(report.authorizationStatus == .denied)
        #expect(report.addedCount == 0)
    }

    @Test("authorization-request failure remains visible in the typed report")
    func authorizationRequestFailureIsReported() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .failure(FakeNotificationCenterClient.AddError.rejected)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [request()], failures: [])
        )
        #expect(report.authorizationStatus == .unknown)
        #expect(report.addFailures == [.authorizationRequestFailed])
    }

    @Test("planning failures are preserved in the reconciliation report")
    func planningFailuresArePreserved() async {
        let itemID = UUID()
        let failure = NotificationPlanningFailure.recurrenceLimitExceeded(itemID: itemID)
        let report = await NotificationReconciler(center: FakeNotificationCenterClient()).reconcile(
            plan: NotificationRequestPlan(requests: [], failures: [failure])
        )
        #expect(report.planningFailures == [failure])
    }

    @Test("unknown authorization status does not add desired requests")
    func unknownAuthorizationDoesNotAddRequests() async {
        let center = FakeNotificationCenterClient(status: .unknown)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [request()], failures: [])
        )
        #expect(report.authorizationStatus == .unknown)
        #expect(report.addedCount == 0)
        #expect(center.pending.isEmpty)
    }

    @Test("concurrent submission leaves newest plan as final pending state")
    func concurrentSubmissionLeavesNewestPlanAsFinalPendingState() async {
        let first = request(id: "soren.v2.charge.first.20260812.3")
        let second = request(id: "soren.v2.charge.second.20260912.3")
        let firstPlan = NotificationRequestPlan(requests: [first], failures: [])
        let secondPlan = NotificationRequestPlan(requests: [second], failures: [])
        let center = FakeNotificationCenterClient()
        let reconciler = NotificationReconciler(center: center)
        let secondSubmission = NotificationTestGate()

        center.suspendNextAdd()
        let firstReconciliation = Task { @MainActor in
            await reconciler.reconcile(plan: firstPlan)
        }

        await center.waitUntilAddIsSuspended()

        let secondReconciliation = Task { @MainActor in
            secondSubmission.signal()
            return await reconciler.reconcile(plan: secondPlan)
        }

        await secondSubmission.wait()
        center.resumeSuspendedAdd()

        _ = await firstReconciliation.value
        _ = await secondReconciliation.value

        #expect(center.pending == [second.id])
        #expect(!center.pending.contains(first.id))
        #expect(center.added.map(\.id) == [first.id, second.id])
    }
}

@Suite("Notification refresh coordination")
@MainActor
struct NotificationRefreshCoordinatorTests {
    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Moscow") ?? .gmt
        return calendar
    }

    private func coordinator(
        fixture: InMemoryPersistenceFixture,
        center: FakeNotificationCenterClient
    ) -> NotificationRefreshCoordinator {
        NotificationRefreshCoordinator(
            repository: fixture.recurringItems,
            planner: NotificationRequestPlanner(
                calendar: calendar(),
                locale: Locale(identifier: "en_US"),
                bundle: Bundle(identifier: "com.alexey.soren") ?? .main
            ),
            reconciler: NotificationReconciler(center: center)
        )
    }

    private func item(status: ItemStatus = .active) -> RecurringItem {
        var item = RecurringItem(
            title: "Spotify",
            amount: 599,
            currencyCode: "RUB",
            nextChargeDate: Date(timeIntervalSince1970: 1_786_579_200)
        )
        item.status = status
        return item
    }

    @Test("refresh builds desired requests from the complete persisted collection")
    func refreshBuildsCompleteDesiredState() async throws {
        let fixture = try InMemoryPersistenceFixture()
        try fixture.recurringItems.save(item())
        let center = FakeNotificationCenterClient()
        let outcome = await coordinator(fixture: fixture, center: center).reconcileCurrentState()
        #expect(center.pending.count == 1)
        #expect({ if case .reconciled = outcome { true } else { false } }())
    }

    @Test("refresh of an empty repository reconciles an empty desired set")
    func emptyRefreshReconcilesEmptyPlan() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let center = FakeNotificationCenterClient(pending: ["soren.charge.legacy"])
        let outcome = await coordinator(fixture: fixture, center: center).reconcileCurrentState()
        #expect(center.pending.isEmpty)
        #expect({ if case .reconciled = outcome { true } else { false } }())
    }

    @Test("refresh removes pending requests when the persisted item is paused")
    func pausedRefreshRemovesOwnedRequests() async throws {
        let fixture = try InMemoryPersistenceFixture()
        try fixture.recurringItems.save(item(status: .paused))
        let center = FakeNotificationCenterClient(pending: ["soren.v2.charge.legacy.20260812.3"])
        _ = await coordinator(fixture: fixture, center: center).reconcileCurrentState()
        #expect(center.pending.isEmpty)
    }

    @Test("refresh clears delivered Soren notifications from authoritative state")
    func refreshClearsDeliveredOwnedRequests() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let center = FakeNotificationCenterClient(delivered: ["soren.trial.legacy"])
        _ = await coordinator(fixture: fixture, center: center).reconcileCurrentState()
        #expect(center.delivered.isEmpty)
    }

    @Test("refresh leaves unrelated pending requests untouched")
    func refreshPreservesUnrelatedPendingRequests() async throws {
        let fixture = try InMemoryPersistenceFixture()
        let center = FakeNotificationCenterClient(pending: ["other.feature.pending"])
        _ = await coordinator(fixture: fixture, center: center).reconcileCurrentState()
        #expect(center.pending == ["other.feature.pending"])
    }
}
