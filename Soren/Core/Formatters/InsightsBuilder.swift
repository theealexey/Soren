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

    static func build(from upcomingCharges: [RecurringItem], today: CivilDate) throws -> [InsightData] {
        var result: [InsightData] = []

        let overdueCount = try upcomingCharges.filter { try $0.daysUntilNextCharge(from: today) < 0 }.count
        if overdueCount > 0 {
            result.append(InsightData(
                icon: "exclamationmark.triangle.fill",
                title: String(localized: "\(overdueCount) просроченных списаний"),
                subtitle: String(localized: "Проверьте способы оплаты"),
                severity: .critical
            ))
        }

        // Use count directly — all saved items have amount > 0, so count >= 2 implies total > 0.
        if upcomingCharges.count >= 2 {
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
