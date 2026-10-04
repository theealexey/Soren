import Foundation

// MARK: - Use Case: Get Alerts

/// Fetches and groups recurring items that require user attention.
/// Groups by urgency: overdue, failed, due today, due soon, trial ending.
@MainActor
struct GetAlerts {

    private let repository: any RecurringItemRepository
    private let now: () -> Date
    private let timeZone: () -> TimeZone

    init(repository: any RecurringItemRepository, now: @escaping () -> Date = { .now }, timeZone: @escaping () -> TimeZone = { .current }) {
        self.repository = repository
        self.now = now
        self.timeZone = timeZone
    }

    func execute(chargeAlertDays: Int = 7, trialAlertDays: Int = 7) throws -> AlertsResult {
        let today = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
        let excludedStatuses: Set<ItemStatus> = [.cancelled, .paused, .archived]

        // fetchActive() uses a SwiftData predicate — avoids loading archived/cancelled rows.
        let items = try repository.fetchActive()
            .filter { !excludedStatuses.contains($0.status) }

        var overdue: [RecurringItem] = []
        var failed: [RecurringItem] = []
        var dueToday: [RecurringItem] = []
        var dueSoon: [RecurringItem] = []
        var trialEnding: [RecurringItem] = []

        for item in items {
            if item.status == .failed {
                failed.append(item)
                continue
            }

            if let trialDays = try item.daysUntilTrialEnd(from: today), trialDays <= trialAlertDays {
                trialEnding.append(item)
            }

            let daysUntil = try item.daysUntilNextCharge(from: today)

            if daysUntil < 0 {
                overdue.append(item)
            } else if daysUntil == 0 {
                dueToday.append(item)
            } else if daysUntil <= chargeAlertDays {
                dueSoon.append(item)
            }
        }

        // Sort each group by urgency (most urgent first)
        overdue.sort { $0.nextChargeDate < $1.nextChargeDate }
        failed.sort { $0.nextChargeDate < $1.nextChargeDate }
        dueToday.sort { $0.title < $1.title }
        dueSoon.sort { $0.nextChargeDate < $1.nextChargeDate }
        trialEnding.sort {
            ($0.trialEndDate ?? .distantFuture) < ($1.trialEndDate ?? .distantFuture)
        }

        return AlertsResult(
            overdue: overdue,
            failed: failed,
            dueToday: dueToday,
            dueSoon: dueSoon,
            trialEnding: trialEnding
        )
    }
}

// MARK: - Alerts Result

struct AlertsResult: Sendable {
    let overdue: [RecurringItem]
    let failed: [RecurringItem]
    let dueToday: [RecurringItem]
    let dueSoon: [RecurringItem]
    let trialEnding: [RecurringItem]

    var totalCount: Int {
        overdue.count + failed.count + dueToday.count + dueSoon.count + trialEnding.count
    }

    var isEmpty: Bool { totalCount == 0 }

    var criticalCount: Int { overdue.count + failed.count }
}
