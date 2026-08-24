import Foundation

// MARK: - Monthly Plan Hero

struct MonthlyPlanHeroPresentation: Equatable, Sendable {
    enum PrimaryStyle: Equatable, Sendable {
        case financialValue
        case statement
    }

    let title: String
    let primary: String
    let primaryStyle: PrimaryStyle
    let leadingSupport: String
    let trailingSupportLabel: String?
    let trailingSupportValue: String?
    let accessibilityLabel: String
}

// MARK: - Upcoming Charges

struct UpcomingChargePresentation: Identifiable, Equatable, Sendable {
    let item: RecurringItem
    let providerName: String
    let amount: String
    let chargeDate: String
    let accessibilityLabel: String

    var id: UUID { item.id }
}

struct UpcomingChargesPresentation: Equatable, Sendable {
    let rows: [UpcomingChargePresentation]
}

// MARK: - Home Screen State

/// Complete presentation snapshot for the production Soft Club Overview.
struct HomeScreenState: Equatable, Sendable {
    let monthLabel: String
    let monthlyPlan: MonthlyPlanHeroPresentation
    let overviewInsight: OverviewInsightPresentation?
    let upcoming: UpcomingChargesPresentation
    let isLoaded: Bool
    let hasError: Bool
}
