#if DEBUG
import Testing
import Foundation
@testable import Soren

@Suite("Notification diagnostics")
@MainActor
struct NotificationDiagnosticsTests {
    @Test("snapshot filters unrelated requests and does not mutate notification state")
    func snapshotIsOwnedAndReadOnly() async {
        let center = FakeNotificationCenterClient(
            pending: ["soren.v2.charge.item.20260812.3", "other.pending"],
            delivered: ["soren.trial.item", "other.delivered"]
        )
        let provider = NotificationDiagnosticsProvider(
            center: center,
            observation: NotificationReconciliationObservation()
        )
        let result = await provider.loadSnapshot(now: .distantPast)

        guard case .loaded(let snapshot) = result else {
            Issue.record("Expected diagnostics snapshot")
            return
        }
        #expect(snapshot.pending.map(\.identifier) == ["soren.v2.charge.item.20260812.3"])
        #expect(snapshot.delivered.map(\.identifier) == ["soren.trial.item"])
        #expect(center.added.isEmpty)
        #expect(center.removedPending.isEmpty)
        #expect(center.removedDelivered.isEmpty)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("snapshot maps v2 metadata and preserves legacy identifiers without content")
    func snapshotMapsSafeMetadata() async {
        let center = FakeNotificationCenterClient()
        center.diagnosticPendingOverride = [
            NotificationDiagnosticPendingRequest(
                identifier: "soren.v2.charge.12345678-1234-1234-1234-123456789abc.20260812.3",
                fireDate: .distantFuture,
                triggerKind: "calendar",
                repeats: false
            ),
            NotificationDiagnosticPendingRequest(
                identifier: "soren.charge.legacy",
                fireDate: nil,
                triggerKind: "other",
                repeats: nil
            )
        ]
        center.diagnosticDeliveredOverride = [
            NotificationDiagnosticDeliveredRequest(
                identifier: "soren.v2.trial.12345678-1234-1234-1234-123456789abc.20260820.1",
                deliveredDate: .distantPast
            )
        ]
        let provider = NotificationDiagnosticsProvider(
            center: center,
            observation: NotificationReconciliationObservation()
        )

        let result = await provider.loadSnapshot(now: .distantPast)

        guard case .loaded(let snapshot) = result else {
            Issue.record("Expected diagnostics snapshot")
            return
        }
        #expect(snapshot.pending.count == 2)
        #expect(snapshot.pending[0].identity.kind == "charge")
        #expect(snapshot.pending[0].identity.itemSuffix == "56789abc")
        #expect(snapshot.pending[0].identity.occurrenceLocalDate == "2026-08-12")
        #expect(snapshot.pending[0].identity.offsetDays == 3)
        #expect(snapshot.pending[0].triggerKind == "calendar")
        #expect(snapshot.pending[0].repeats == false)
        #expect(snapshot.pending[1].identity.kind == nil)
        #expect(snapshot.delivered[0].identity.kind == "trial")
        #expect(snapshot.delivered[0].deliveredDate == .distantPast)
        #expect(!Mirror(reflecting: snapshot.pending[0]).children.compactMap(\.label).contains("title"))
        #expect(!Mirror(reflecting: snapshot.pending[0]).children.compactMap(\.label).contains("body"))
        #expect(center.authorizationRequestCount == 0)
        #expect(center.added.isEmpty)
        #expect(center.removedPending.isEmpty)
        #expect(center.removedDelivered.isEmpty)
    }

    @Test("last reconciliation presentation includes authorization and failure category")
    func lastReconciliationPresentationIncludesAuthorizationAndFailureCategory() {
        let record = NotificationReconciliationRecord(
            startedAt: .distantPast,
            completedAt: .distantFuture,
            source: .permissionGrant,
            desiredCount: 2,
            removedPendingCount: 1,
            removedDeliveredCount: 0,
            addedCount: 1,
            failedAddCount: 1,
            planningFailureCount: 1,
            authorizationStatus: .provisional,
            failureCategory: .planningAndAdd
        )

        #expect(
            NotificationDiagnosticsView.authorizationText(record.authorizationStatus)
                == String(localized: "Включены тихо")
        )
        #expect(
            NotificationDiagnosticsView.failureText(record.failureCategory)
                == String(localized: "Ошибки планирования и добавления")
        )
        #expect(!Mirror(reflecting: record).children.compactMap(\.label).contains("amount"))
        #expect(!Mirror(reflecting: record).children.compactMap(\.label).contains("body"))
    }
}
#endif
