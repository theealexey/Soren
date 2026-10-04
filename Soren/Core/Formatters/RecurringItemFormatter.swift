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
    static func badge(for item: RecurringItem, today: CivilDate? = nil) -> SorenListRow.Badge? {
        if let today = today ?? (try? BillingDatePresentation.today()),
           (try? item.isActiveTrial(on: today)) == true { return .trial }
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
    static func chargeSubtitle(for item: RecurringItem, today: CivilDate? = nil) -> String {
        guard let days = effectiveDays(for: item, today: today) else { return "" }
        if days == 0 { return String(localized: "Списание сегодня") }
        if days == 1 { return String(localized: "Списание завтра") }
        if days < 0 { return String(localized: "Дата списания была \(abs(days)) дн. назад") }
        return String(localized: "Через \(days) дн.")
    }

    /// Formatted subtitle for library list rows — handles all statuses.
    static func subtitle(for item: RecurringItem, today: CivilDate? = nil) -> String {
        switch item.status {
        case .cancelled:
            return String(localized: "Отменена")
        case .paused:
            return String(localized: "На паузе")
        case .archived:
            return String(localized: "В архиве")
        default:
            guard let days = effectiveDays(for: item, today: today) else { return "" }
            if days < 0 { return String(localized: "Дата списания была \(abs(days)) дн. назад") }
            if days == 0 { return String(localized: "Списание сегодня") }
            if days == 1 { return String(localized: "Списание завтра") }
            return String(localized: "Списание через \(days) дн.")
        }
    }

    // MARK: - Private helpers

    private static func effectiveDays(for item: RecurringItem, today: CivilDate?) -> Int? {
        guard let today = today ?? (try? BillingDatePresentation.today()),
              let date = try? item.effectiveNextChargeDate(relativeTo: today),
              let day = try? BillingCivilDay.civilDate(fromCanonicalDate: date) else { return nil }
        return try? BillingCivilDay.days(from: today, to: day)
    }

    // MARK: - Trial Display

    /// Formatted subtitle for trial insight cards.
    static func trialSubtitle(for item: RecurringItem, today: CivilDate? = nil) -> String {
        guard let today = today ?? (try? BillingDatePresentation.today()),
              let daysLeft = try? item.daysUntilTrialEnd(from: today) else {
            return String(localized: "Пробный период")
        }
        if daysLeft <= 0 { return String(localized: "Пробный период заканчивается сегодня") }
        if daysLeft == 1 { return String(localized: "Остался 1 день") }
        return String(localized: "Осталось \(daysLeft) дн.")
    }

    /// Determines trial urgency severity for insight cards.
    static func trialSeverity(for item: RecurringItem, today: CivilDate? = nil) -> InsightCard.Severity {
        guard let today = today ?? (try? BillingDatePresentation.today()),
              let days = try? item.daysUntilTrialEnd(from: today) else { return .info }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .info
    }

    /// Plural-aware label for a trial count chip.
    ///
    /// Uses xcstrings CLDR rules — `count` drives plural category selection.
    /// Returns the full "N word" string (e.g. "1 пробный", "3 пробных", "1 trial"),
    /// intended for use as the chip's `value:` parameter with `label: ""`.
    static func trialCountLabel(count: Int) -> String {
        String(localized: "\(count) пробных")
    }
}
