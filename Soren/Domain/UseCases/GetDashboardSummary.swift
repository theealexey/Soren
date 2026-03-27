import Foundation

// MARK: - Dashboard Summary

/// Aggregated financial snapshot for the Home screen.
/// Computed from active recurring items — no persistence needed.
struct DashboardSummary: Equatable, Sendable {
    /// Total monthly cost across all active items.
    let monthlyTotal: Decimal
    /// Projected yearly cost (monthlyTotal × 12).
    let yearlyProjection: Decimal
    /// Number of active (non-archived, non-cancelled) items.
    let activeItemCount: Int
    /// Number of active trials.
    let activeTrialCount: Int

    static let empty = DashboardSummary(
        monthlyTotal: 0,
        yearlyProjection: 0,
        activeItemCount: 0,
        activeTrialCount: 0
    )
}

// MARK: - Use Case

/// Computes the dashboard financial summary from active recurring items.
@MainActor
struct GetDashboardSummary {

    private let repository: SwiftDataRecurringItemRepository

    init(repository: SwiftDataRecurringItemRepository) {
        self.repository = repository
    }

    func execute() throws -> DashboardSummary {
        let items = try repository.fetchActive()

        let monthlyTotal = items.reduce(Decimal.zero) { sum, item in
            sum + item.monthlyEquivalent
        }

        let trialCount = items.filter { $0.status == .trial }.count

        return DashboardSummary(
            monthlyTotal: monthlyTotal,
            yearlyProjection: monthlyTotal * 12,
            activeItemCount: items.count,
            activeTrialCount: trialCount
        )
    }
}
