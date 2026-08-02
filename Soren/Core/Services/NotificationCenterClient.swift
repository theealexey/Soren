import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    var permitsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied, .unknown:
            false
        }
    }
}

/// The protocol exists solely at the `UNUserNotificationCenter` boundary: the
/// system singleton is not constructible in deterministic unit tests.
@MainActor
protocol NotificationCenterClient: AnyObject {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> NotificationAuthorizationStatus
    func pendingRequestIdentifiers() async -> [String]
    func deliveredNotificationIdentifiers() async -> [String]
    func add(_ request: PlannedNotificationRequest) async throws
    func removePending(identifiers: [String])
    func removeDelivered(identifiers: [String])
}

@MainActor
final class UNUserNotificationCenterClient: NotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        map(await center.notificationSettings().authorizationStatus)
    }

    func requestAuthorization() async throws -> NotificationAuthorizationStatus {
        _ = try await center.requestAuthorization(options: [.alert, .sound])
        return await authorizationStatus()
    }

    func pendingRequestIdentifiers() async -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func deliveredNotificationIdentifiers() async -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func add(_ request: PlannedNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: request.trigger.timeZoneIdentifier)
        components.year = request.trigger.year
        components.month = request.trigger.month
        components.day = request.trigger.day
        components.hour = request.trigger.hour
        components.minute = request.trigger.minute

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: request.trigger.repeats
        )
        try await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    func removePending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func map(_ status: UNAuthorizationStatus) -> NotificationAuthorizationStatus {
        switch status {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .unknown
        }
    }
}

#if DEBUG
struct NotificationDiagnosticPendingRequest: Sendable, Equatable {
    let identifier: String
    let fireDate: Date?
    let triggerKind: String
    let repeats: Bool?
}

struct NotificationDiagnosticDeliveredRequest: Sendable, Equatable {
    let identifier: String
    let deliveredDate: Date
}

/// DEBUG-only read boundary for non-sensitive, Soren-owned request metadata.
@MainActor
protocol NotificationDiagnosticsReading: AnyObject {
    func pendingNotificationDiagnostics() async -> [NotificationDiagnosticPendingRequest]
    func deliveredNotificationDiagnostics() async -> [NotificationDiagnosticDeliveredRequest]
}

extension UNUserNotificationCenterClient: NotificationDiagnosticsReading {
    func pendingNotificationDiagnostics() async -> [NotificationDiagnosticPendingRequest] {
        await center.pendingNotificationRequests().map { request in
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                return NotificationDiagnosticPendingRequest(
                    identifier: request.identifier,
                    fireDate: trigger.nextTriggerDate(),
                    triggerKind: "calendar",
                    repeats: trigger.repeats
                )
            }
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                return NotificationDiagnosticPendingRequest(
                    identifier: request.identifier,
                    fireDate: trigger.nextTriggerDate(),
                    triggerKind: "timeInterval",
                    repeats: trigger.repeats
                )
            }
            return NotificationDiagnosticPendingRequest(
                identifier: request.identifier,
                fireDate: nil,
                triggerKind: "other",
                repeats: nil
            )
        }
    }

    func deliveredNotificationDiagnostics() async -> [NotificationDiagnosticDeliveredRequest] {
        await center.deliveredNotifications().map {
            NotificationDiagnosticDeliveredRequest(identifier: $0.request.identifier, deliveredDate: $0.date)
        }
    }
}
#endif
