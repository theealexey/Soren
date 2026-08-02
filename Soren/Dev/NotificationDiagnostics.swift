#if DEBUG
import Foundation

struct NotificationDiagnosticsSnapshot: Sendable, Equatable {
    let authorizationStatus: NotificationAuthorizationStatus
    let capturedAt: Date
    let pending: [NotificationDiagnosticPendingItem]
    let delivered: [NotificationDiagnosticDeliveredItem]
    let latestReconciliation: NotificationReconciliationRecord?
}

struct NotificationDiagnosticRequestIdentity: Sendable, Equatable {
    let kind: String?
    let itemSuffix: String?
    let occurrenceLocalDate: String?
    let offsetDays: Int?

    init(identifier: String) {
        let parts = identifier.split(separator: ".").map(String.init)
        guard parts.count >= 6, parts[0] == "soren", parts[1] == "v2" else {
            kind = nil
            itemSuffix = nil
            occurrenceLocalDate = nil
            offsetDays = nil
            return
        }
        kind = parts[2]
        itemSuffix = String(parts[3].suffix(8))
        occurrenceLocalDate = Self.localDate(from: parts[4])
        offsetDays = Int(parts[5])
    }

    private static func localDate(from key: String) -> String? {
        guard key.count == 8 else { return nil }
        let year = key.prefix(4)
        let month = key.dropFirst(4).prefix(2)
        let day = key.suffix(2)
        guard Int(year) != nil, Int(month) != nil, Int(day) != nil else { return nil }
        return "\(year)-\(month)-\(day)"
    }
}

struct NotificationDiagnosticPendingItem: Sendable, Equatable {
    let identifier: String
    let identity: NotificationDiagnosticRequestIdentity
    let fireDate: Date?
    let triggerKind: String
    let repeats: Bool?
}

struct NotificationDiagnosticDeliveredItem: Sendable, Equatable {
    let identifier: String
    let identity: NotificationDiagnosticRequestIdentity
    let deliveredDate: Date
}

enum NotificationDiagnosticsSnapshotResult: Sendable, Equatable {
    case loaded(NotificationDiagnosticsSnapshot)
}

/// Read-only diagnostics source. It filters by the Soren namespace before any
/// value reaches the debug UI, and never mutates notification state.
@MainActor
final class NotificationDiagnosticsProvider {
    private let center: any NotificationCenterClient
    private let reader: any NotificationDiagnosticsReading
    private let observation: NotificationReconciliationObservation

    init(
        center: any NotificationCenterClient & NotificationDiagnosticsReading,
        observation: NotificationReconciliationObservation
    ) {
        self.center = center
        self.reader = center
        self.observation = observation
    }

    func loadSnapshot(now: Date = .now) async -> NotificationDiagnosticsSnapshotResult {
        let authorization = await center.authorizationStatus()
        let pending = await reader.pendingNotificationDiagnostics()
            .filter { $0.identifier.hasPrefix("soren.") }
            .map {
                NotificationDiagnosticPendingItem(
                    identifier: $0.identifier,
                    identity: NotificationDiagnosticRequestIdentity(identifier: $0.identifier),
                    fireDate: $0.fireDate,
                    triggerKind: $0.triggerKind,
                    repeats: $0.repeats
                )
            }
        let delivered = await reader.deliveredNotificationDiagnostics()
            .filter { $0.identifier.hasPrefix("soren.") }
            .map {
                NotificationDiagnosticDeliveredItem(
                    identifier: $0.identifier,
                    identity: NotificationDiagnosticRequestIdentity(identifier: $0.identifier),
                    deliveredDate: $0.deliveredDate
                )
            }
        return .loaded(NotificationDiagnosticsSnapshot(
            authorizationStatus: authorization,
            capturedAt: now,
            pending: pending,
            delivered: delivered,
            latestReconciliation: observation.latestRecord
        ))
    }
}
#endif
