import Foundation

/// Current non-trial obligations used for normalized cost, independently of
/// the complete scheduled-occurrence forecast.
@MainActor
struct GetAnalyticsCurrentObligations {
    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute(today: CivilDate) throws -> [RecurringItem] {
        try repository.fetchAll().filter { item in
            guard item.archivedAt == nil else { return false }
            switch item.status {
            case .active, .dueSoon, .dueToday, .overdue, .failed:
                break
            case .trial, .paused, .cancelled, .archived:
                return false
            }
            guard try BillingCivilDay.civilDate(fromCanonicalDate: item.startDate) <= today else {
                return false
            }
            if let endDate = item.endDate {
                return try BillingCivilDay.civilDate(fromCanonicalDate: endDate) >= today
            }
            return true
        }
    }
}
