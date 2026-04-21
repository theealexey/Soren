import Foundation

// MARK: - Recurring Item Formatter

/// Single source of truth for recurring item display logic.
/// Pure functions — no dependencies on ViewModels or state.
enum RecurringItemFormatter {

    // MARK: - Billing Cycle

    /// Maps BillingCycle to the AmountLabel CycleLabel used in list rows.
    static func cycleLabel(for cycle: BillingCycle) -> AmountLabel.CycleLabel {
        switch cycle {
        case .weekly:       .weekly
        case .monthly:      .monthly
        case .annual:       .yearly
        case .quarterly:    .custom(String(localized: "кв"))
        case .semiannual:   .custom(String(localized: "п/г"))
        case .custom(let d): .custom(String(localized: "\(d)д"))
        }
    }

    // MARK: - Badges

    /// Determines the badge to show on a list row.
    static func badge(for item: RecurringItem) -> SorenListRow.Badge? {
        if item.isActiveTrial { return .trial }
        switch item.status {
        case .failed:   return .failed
        case .paused:   return .paused
        case .dueSoon, .dueToday:
            return .dueSoon
        case .cancelled: return nil
        default:
            return item.billingCycle.isLongCycle ? .annual : nil
        }
    }

    // MARK: - Charge Subtitles

    /// Formatted subtitle for upcoming charge rows.
    static func chargeSubtitle(for item: RecurringItem) -> String {
        let days = daysFromToday(to: item.effectiveNextChargeDate())
        if days == 0 { return String(localized: "Списание сегодня") }
        if days == 1 { return String(localized: "Списание завтра") }
        if days < 0 { return String(localized: "Дата списания была \(abs(days)) дн. назад") }
        return String(localized: "Через \(days) дн.")
    }

    /// Formatted subtitle for library list rows — handles all statuses.
    static func subtitle(for item: RecurringItem) -> String {
        switch item.status {
        case .cancelled:
            return String(localized: "Отменена")
        case .paused:
            return String(localized: "На паузе")
        case .archived:
            return String(localized: "В архиве")
        default:
            let days = daysFromToday(to: item.effectiveNextChargeDate())
            if days < 0 { return String(localized: "Дата списания была \(abs(days)) дн. назад") }
            if days == 0 { return String(localized: "Списание сегодня") }
            if days == 1 { return String(localized: "Списание завтра") }
            return String(localized: "Списание через \(days) дн.")
        }
    }

    // MARK: - Private helpers

    private static func daysFromToday(to date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
    }

    // MARK: - Trial Display

    /// Formatted subtitle for trial insight cards.
    static func trialSubtitle(for item: RecurringItem) -> String {
        guard let daysLeft = item.daysUntilTrialEnd else {
            return String(localized: "Пробный период")
        }
        if daysLeft <= 0 { return String(localized: "Пробный период заканчивается сегодня") }
        if daysLeft == 1 { return String(localized: "Остался 1 день") }
        return String(localized: "Осталось \(daysLeft) дн.")
    }

    /// Determines trial urgency severity for insight cards.
    static func trialSeverity(for item: RecurringItem) -> InsightCard.Severity {
        guard let days = item.daysUntilTrialEnd else { return .info }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .info
    }

    /// Russian pluralization for "пробный период" count label.
    static func pluralTrial(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return String(localized: "пробный") }
        return String(localized: "пробных")
    }
}
