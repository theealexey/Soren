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

    @Test("not-determined authorization does not request permission or add desired requests")
    func notDeterminedDoesNotRequestAuthorization() async {
        let desired = request()
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.authorized)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [desired], failures: [])
        )
        #expect(report.authorizationStatus == .notDetermined)
        #expect(report.addedCount == 0)
        #expect(center.authorizationRequestCount == 0)
        #expect(center.pending.isEmpty)
    }

    @Test("not-determined authorization remains explicit without a prompt")
    func authorizationNotDeterminedIsExplicit() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.denied)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [request()], failures: [])
        )
        #expect(report.authorizationStatus == .notDetermined)
        #expect(report.addedCount == 0)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("provisional authorization adds desired requests")
    func provisionalAuthorizationAddsRequests() async {
        let desired = request()
        let center = FakeNotificationCenterClient(status: .provisional)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [desired], failures: [])
        )
        #expect(report.authorizationStatus == .provisional)
        #expect(report.addedCount == 1)
        #expect(center.pending == [desired.id])
    }

    @Test("ephemeral authorization adds desired requests without requesting permission")
    func ephemeralAuthorizationAddsRequests() async {
        let desired = request()
        let center = FakeNotificationCenterClient(status: .ephemeral)
        let report = await NotificationReconciler(center: center).reconcile(
            plan: NotificationRequestPlan(requests: [desired], failures: [])
        )
        #expect(report.authorizationStatus == .ephemeral)
        #expect(report.addedCount == 1)
        #expect(center.authorizationRequestCount == 0)
        #expect(center.pending == [desired.id])
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
        #expect(center.authorizationRequestCount == 0)
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
            startDate: Date(timeIntervalSince1970: 1_786_579_200),
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

@MainActor
struct RenewalNotificationReconciliationTests {
    private func request(_ index: Int, kind: NotificationRequestKind = .charge,
                         fire: Date? = nil) -> PlannedNotificationRequest {
        let key = "20300101"
        let fireDate = fire ?? Date(timeIntervalSince1970: 1_893_488_400 + Double(index) * 60)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return PlannedNotificationRequest(
            id: String(format: "soren.v2.%@.item%03d.%@.0", kind.rawValue, index, key),
            itemID: UUID(), kind: kind,
            occurrenceDate: Date(timeIntervalSince1970: 1_893_456_000), occurrenceLocalDateKey: key,
            reminderOffsetDays: 0, fireDate: fireDate,
            trigger: NotificationTriggerPlan(year: 2030, month: 1, day: 1,
                hour: calendar.component(.hour, from: fireDate), minute: calendar.component(.minute, from: fireDate),
                timeZoneIdentifier: "GMT", repeats: false),
            title: "Synthetic", body: "Synthetic decision")
    }

    private func plan(_ requests: [PlannedNotificationRequest]) -> NotificationRequestPlan {
        NotificationRequestPlan(requests: requests, failures: [])
    }

    @Test("Capacity selects nearest requests before add, independently of input order", arguments: [0, 60, 61, 96], [false, true])
    func nearestSelection(count: Int, reversed: Bool) async {
        let requests = (0..<count).map { request($0, kind: $0.isMultiple(of: 2) ? .charge : .renewalDecision) }
        let center = FakeNotificationCenterClient()
        let report = await NotificationReconciler(center: center).reconcile(plan: plan(reversed ? Array(requests.reversed()) : requests))
        let expected = Array(requests.prefix(60))
        #expect(center.addAttempts == expected.map(\.id))
        #expect(center.pending == Set(expected.map(\.id)))
        #expect(report.desiredCount == count && report.addedCount == min(count, 60))
        #expect(report.capacityOmittedIdentifiers == requests.dropFirst(expected.count).map(\.id))
        #expect(report.addFailures.isEmpty && report.missingPendingIdentifiers.isEmpty)
        #expect(report.pendingCountAfterReconciliation == expected.count)
        #expect(report.hasSchedulingIssues == (count > 60))
        #expect(center.pendingReadCount == 2)
    }

    @Test("Same-time capacity uses trial, charge, decision then stable ID")
    func equalTimePriority() async {
        let sameTime = Date(timeIntervalSince1970: 1_893_488_400)
        let trials = (0..<25).map { request($0, kind: .trial, fire: sameTime) }
        let charges = (0..<25).map { request($0, kind: .charge, fire: sameTime) }
        let decisions = (0..<25).map { request($0, kind: .renewalDecision, fire: sameTime) }
        let source = Array((decisions + charges + trials).reversed())
        let center = FakeNotificationCenterClient()
        let report = await NotificationReconciler(center: center).reconcile(plan: plan(source))
        #expect(center.addAttempts == (trials + charges + Array(decisions.prefix(10))).map(\.id))
        #expect(report.capacityOmittedIdentifiers == decisions.dropFirst(10).map(\.id))
        #expect(report.hasSchedulingIssues)
    }

    @Test("Non-owned pending requests consume slots and are never removed", arguments: [5, 60, 65])
    func competingPending(count: Int) async {
        let other = Set((0..<count).map { "other.feature.\($0)" })
        let old = "soren.v2.renewalDecision.old.20300101.0"
        let center = FakeNotificationCenterClient(pending: other.union([old]))
        let requests = (0..<60).map { request($0) }
        let available = max(0, 60 - count)
        let report = await NotificationReconciler(center: center).reconcile(plan: plan(requests))
        #expect(center.pending == other.union(requests.prefix(available).map(\.id)))
        #expect(center.removedPending == [old])
        #expect(center.addAttempts.count == available)
        #expect(report.capacityOmittedIdentifiers == requests.dropFirst(available).map(\.id))
        #expect(report.pendingBudgetExceededCount == max(0, count - 60))
    }

    @Test("Capacity, add rejection and silent retention loss are separate facts")
    func retentionIsVerified() async {
        let requests = (0..<61).map { request($0) }
        let center = FakeNotificationCenterClient()
        center.rejectedIDs = [requests[1].id]
        center.silentlyDroppedIDs = [requests[2].id]
        let failure = NotificationPlanningFailure.invalidDate(itemID: requests[0].itemID)
        let report = await NotificationReconciler(center: center).reconcile(plan: NotificationRequestPlan(requests: requests, failures: [failure]))
        #expect(report.desiredCount == 61 && report.addedCount == 59)
        #expect(report.capacityOmittedIdentifiers == [requests[60].id])
        #expect(report.addFailures == [.addFailed(identifier: requests[1].id)])
        #expect(report.missingPendingIdentifiers == [requests[1].id, requests[2].id])
        #expect(report.planningFailures == [failure])
        #expect(report.pendingCountAfterReconciliation == 58 && report.hasSchedulingIssues)
        #expect(!center.addAttempts.contains(requests[60].id))
    }

    @Test("Concurrent foreign additions are reported without deleting them")
    func concurrentForeignOverflow() async {
        let center = FakeNotificationCenterClient()
        center.pendingAddedDuringNextAdd = ["other.concurrent"]
        let report = await NotificationReconciler(center: center).reconcile(plan: plan((0..<60).map { request($0) }))
        #expect(report.pendingCountAfterReconciliation == 61 && report.pendingBudgetExceededCount == 1)
        #expect(report.hasSchedulingIssues && center.pending.contains("other.concurrent"))
        #expect(!center.removedPending.contains("other.concurrent"))
    }

    @Test("Permission outcomes retain configuration and never prompt", arguments: [
        NotificationAuthorizationStatus.denied, .notDetermined, .unknown, .provisional, .ephemeral
    ])
    func permissions(status: NotificationAuthorizationStatus) async {
        let center = FakeNotificationCenterClient(status: status)
        let desired = request(0, kind: .renewalDecision)
        let report = await NotificationReconciler(center: center).reconcile(plan: plan([desired]))
        #expect(report.authorizationStatus == status && report.desiredCount == 1)
        #expect(report.addedCount == (status.permitsScheduling ? 1 : 0))
        #expect(report.hasSchedulingIssues == !status.permitsScheduling)
        #expect(center.authorizationRequestCount == 0)
        #expect(report.missingPendingIdentifiers.isEmpty)
    }

    @Test("Exact delivered decision namespace is preserved, other owned history is cleaned")
    func deliveredOwnership() async {
        let decision = request(0, kind: .renewalDecision)
        let charge = request(0), trial = request(0, kind: .trial)
        let preserved = Set([decision.id, "other.delivered"])
        let cleaned = Set([charge.id, trial.id, "soren.charge.legacy", "soren.trial.legacy", "soren.v2.renewalDecisionExtra.old"])
        let center = FakeNotificationCenterClient(pending: [decision.id, "other.pending"], delivered: preserved.union(cleaned))
        let report = await NotificationReconciler(center: center).reconcile(plan: plan([decision, charge, trial]))
        #expect(center.delivered == preserved)
        #expect(Set(center.removedDelivered) == cleaned)
        #expect(center.pending == [charge.id, trial.id, "other.pending"])
        #expect(center.addAttempts == [trial.id, charge.id])
        #expect(report.deliveredDecisionSuppressedIdentifiers == [decision.id])
        #expect(report.removedDeliveredCount == cleaned.count && report.desiredCount == 3)
        #expect(report.addedCount == 2 && !report.hasSchedulingIssues)
    }

    @Test("Delivered decision consumes no slot and is not re-added on repeated plans")
    func deliveredDoesNotConsumeBudget() async {
        let decision = request(0, kind: .renewalDecision)
        let requests = (1...60).map { request($0) }
        let center = FakeNotificationCenterClient(delivered: [decision.id])
        let reconciler = NotificationReconciler(center: center)
        for _ in 0..<2 {
            let report = await reconciler.reconcile(plan: plan([decision] + requests))
            #expect(report.desiredCount == 61 && report.addedCount == 60)
            #expect(report.capacityOmittedIdentifiers.isEmpty)
            #expect(report.deliveredDecisionSuppressedIdentifiers == [decision.id])
            #expect(!report.hasSchedulingIssues)
        }
        #expect(center.delivered == [decision.id] && !center.addAttempts.contains(decision.id))
        #expect(center.pending.count == 60)
    }

    @Test("Rapid decision changes and delete converge after a suspended add", arguments: [false, true])
    func newestDecisionPlanWins(deleteLatest: Bool) async {
        let first = request(0, kind: .renewalDecision), changed = request(1, kind: .renewalDecision)
        let center = FakeNotificationCenterClient()
        center.suspendNextAdd()
        let reconciler = NotificationReconciler(center: center)
        let firstTask = Task { @MainActor in await reconciler.reconcile(plan: plan([first])) }
        await center.waitUntilAddIsSuspended()
        let submitted = NotificationTestGate()
        let latestTask = Task { @MainActor in
            submitted.signal()
            return await reconciler.reconcile(plan: plan(deleteLatest ? [] : [changed]))
        }
        await submitted.wait()
        center.resumeSuspendedAdd()
        _ = await firstTask.value
        let result = await latestTask.value
        #expect(center.pending == Set(deleteLatest ? [] : [changed.id]))
        #expect(result.desiredCount == (deleteLatest ? 0 : 1))
        #expect(result.capacityOmittedIdentifiers.isEmpty && result.missingPendingIdentifiers.isEmpty)
        #expect(!result.hasSchedulingIssues)
    }
}

extension RenewalNotificationReconciliationTests {
    @Test("Authoritative updates remove stale pending decision requests but retain delivered history", arguments: [
        "change", "disable", "clear", "pause", "resume", "archive", "cancel", "delete"
    ])
    func persistedDecisionChanges(action: String) async throws {
        let fixture = try InMemoryPersistenceFixture()
        var value = try canonicalTestItem()
        value.chargeReminder = .never
        value.status = action == "resume" ? .paused : .active
        value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 12)
        value.renewalDecisionReminderEnabled = true
        try fixture.recurringItems.save(value)
        let prefix = "soren.v2.renewalDecision.\(value.id.uuidString.lowercased())."
        let history = prefix + "20260810.0", originalPending = prefix + "20260812.0"
        let center = FakeNotificationCenterClient(delivered: [history])
        let now = try canonicalTestDay(1)
        let coordinator = NotificationRefreshCoordinator(repository: fixture.recurringItems,
            reconciler: NotificationReconciler(center: center), timeZone: { .gmt }, now: { now })
        _ = await coordinator.reconcileCurrentState()
        #expect(center.pending == [originalPending])
        var changed = value
        switch action {
        case "change": changed.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 15)
        case "disable": changed.renewalDecisionReminderEnabled = false
        case "clear": changed.renewalDecisionDeadline = nil; changed.renewalDecisionReminderEnabled = false
        case "pause": changed.status = .paused
        case "resume": changed.status = .active
        case "archive": changed.status = .archived
        case "cancel": changed.status = .cancelled
        default: break
        }
        if action == "delete" {
            _ = try await DeleteRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(id: value.id)
            #expect(try fixture.recurringItems.fetch(id: value.id) == nil)
        } else {
            _ = try await UpdateRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(changed)
            let stored = try #require(try fixture.recurringItems.fetch(id: value.id))
            #expect(stored.renewalDecisionDeadline == changed.renewalDecisionDeadline)
            #expect(stored.renewalDecisionReminderEnabled == changed.renewalDecisionReminderEnabled)
        }
        let expected: Set<String>
        switch action {
        case "change": expected = [prefix + "20260815.0"]
        case "pause", "resume": expected = [originalPending]
        default: expected = []
        }
        #expect(center.pending == expected)
        #expect(center.delivered == [history] && !center.removedDelivered.contains(history))
        #expect(center.removedPending.contains(originalPending))
    }

    @Test("Permission cannot disable a persisted decision preference", arguments: [
        NotificationAuthorizationStatus.denied, .notDetermined
    ])
    func persistedPermissionPreference(status: NotificationAuthorizationStatus) async throws {
        let fixture = try InMemoryPersistenceFixture()
        var value = try canonicalTestItem()
        value.chargeReminder = .never
        value.renewalDecisionDeadline = try CivilDate(year: 2026, month: 8, day: 12)
        value.renewalDecisionReminderEnabled = true
        let center = FakeNotificationCenterClient(status: status)
        let now = try canonicalTestDay(1)
        let coordinator = NotificationRefreshCoordinator(repository: fixture.recurringItems,
            reconciler: NotificationReconciler(center: center), timeZone: { .gmt }, now: { now })
        let saved = try await SaveRecurringItem(repository: fixture.recurringItems, notificationCoordinator: coordinator).execute(value)
        guard case .reconciled(let report) = saved.notificationOutcome else { Issue.record("Missing reconciliation report"); return }
        #expect(report.desiredCount == 1 && report.addedCount == 0 && report.hasSchedulingIssues)
        #expect(try fixture.recurringItems.fetch(id: value.id) == saved.item)
        center.status = .authorized
        _ = await coordinator.reconcileCurrentState(source: .other)
        #expect(center.pending.count == 1 && center.authorizationRequestCount == 0)
        #expect(try fixture.recurringItems.fetch(id: value.id) == saved.item)
    }
}
