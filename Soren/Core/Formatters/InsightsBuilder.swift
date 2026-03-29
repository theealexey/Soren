import Foundation

// MARK: - Insights Builder

/// Builds dashboard insight cards from upcoming charges data.
/// Extracted from HomeViewModel to respect SRP.
enum InsightsBuilder {

    struct InsightData {
        let icon: String
        let title: String
        let subtitle: String?
        let severity: InsightCard.Severity
    }

    static func build(from upcomingCharges: [RecurringItem]) -> [InsightData] {
        var result: [InsightData] = []

        let overdueCount = upcomingCharges.filter { $0.daysUntilNextCharge < 0 }.count
        if overdueCount > 0 {
            result.append(InsightData(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "\(overdueCount) просроченных списаний"),
                subtitle: String(localized: "Проверьте способы оплаты"),
                severity: .critical
            ))
        }

        let weekTotal = upcomingCharges.reduce(Decimal.zero) { $0 + $1.amount }
        if weekTotal > 0 && upcomingCharges.count >= 2 {
            result.append(InsightData(
                icon: "calendar.badge.clock",
                title: String(localized: "\(upcomingCharges.count) списаний на этой неделе"),
                subtitle: nil,
                severity: .info
            ))
        }

        let failedCount = upcomingCharges.filter { $0.status == .failed }.count
        if failedCount > 0 {
            result.append(InsightData(
                icon: "creditcard.trianglebadge.exclamationmark",
                title: String(localized: "\(failedCount) неудачных платежей"),
                subtitle: String(localized: "Требуется внимание"),
                severity: .critical
            ))
        }

        return result
    }
}
