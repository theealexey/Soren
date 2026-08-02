import Testing
@testable import Soren

@Suite("Notification permission coordination")
@MainActor
struct NotificationPermissionCoordinatorTests {
    @Test("explicit Settings request asks once and reconciles after authorization")
    func explicitGrantRequestsAndRefreshes() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.authorized)
        let refresh = NotificationReconciliationSpy()
        let coordinator = NotificationPermissionCoordinator(center: center, refreshCoordinator: refresh)

        let outcome = await coordinator.requestAuthorizationFromSettings()

        #expect(outcome == .completed(status: .authorized, refresh: refresh.outcome))
        #expect(center.authorizationRequestCount == 1)
        #expect(refresh.callCount == 1)
    }

    @Test("explicit Settings denial does not reconcile or retry")
    func explicitDenialDoesNotRefresh() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.denied)
        let refresh = NotificationReconciliationSpy()
        let coordinator = NotificationPermissionCoordinator(center: center, refreshCoordinator: refresh)

        let outcome = await coordinator.requestAuthorizationFromSettings()

        #expect(outcome == .completed(status: .denied, refresh: nil))
        #expect(center.authorizationRequestCount == 1)
        #expect(refresh.callCount == 0)
    }

    @Test("permission request failures are typed")
    func requestFailureIsTyped() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .failure(FakeNotificationCenterClient.AddError.rejected)
        let coordinator = NotificationPermissionCoordinator(
            center: center,
            refreshCoordinator: NotificationReconciliationSpy()
        )

        #expect(await coordinator.requestAuthorizationFromSettings() == .requestFailed(status: .notDetermined))
    }

    @Test("stale Enable action does not request authorization when the current state is denied")
    func staleEnableActionDoesNotRequestAuthorizationWhenCurrentStateIsDenied() async {
        let center = FakeNotificationCenterClient(status: .denied)
        let refresh = NotificationReconciliationSpy()
        let coordinator = NotificationPermissionCoordinator(center: center, refreshCoordinator: refresh)

        let outcome = await coordinator.requestAuthorizationFromSettings()

        #expect(outcome == .completed(status: .denied, refresh: nil))
        #expect(center.authorizationRequestCount == 0)
        #expect(refresh.callCount == 0)
    }

    @Test("concurrent explicit requests share one system authorization operation")
    func concurrentExplicitRequestsAreCoalesced() async {
        let center = FakeNotificationCenterClient(status: .notDetermined)
        center.authorizationResult = .success(.authorized)
        center.suspendNextAuthorizationRequest()
        let refresh = NotificationReconciliationSpy()
        let coordinator = NotificationPermissionCoordinator(center: center, refreshCoordinator: refresh)

        let first = Task { @MainActor in
            await coordinator.requestAuthorizationFromSettings()
        }
        await center.waitUntilAuthorizationRequestIsSuspended()

        let second = Task { @MainActor in
            await coordinator.requestAuthorizationFromSettings()
        }
        center.resumeSuspendedAuthorizationRequest()

        let firstOutcome = await first.value
        let secondOutcome = await second.value

        #expect(firstOutcome == .completed(status: .authorized, refresh: refresh.outcome))
        #expect(secondOutcome == firstOutcome)
        #expect(center.authorizationRequestCount == 1)
        #expect(refresh.callCount == 1)
    }
}
