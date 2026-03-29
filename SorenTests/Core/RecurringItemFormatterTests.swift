import Testing
import Foundation
@testable import Soren

// MARK: - Recurring Item Formatter Tests (Adversarial)

/// Tests the shared RecurringItemFormatter — single source of truth
/// for display helpers previously duplicated across ViewModels.

@Suite("RecurringItemFormatter")
struct RecurringItemFormatterTests {

    // MARK: - Helpers

    private func makeItem(
        billingCycle: BillingCycle = .monthly,
        status: ItemStatus = .active,
        nextCharge: Date? = nil,
        trialEndDate: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            amount: 299,
            currencyCode: "RUB",
            billingCycle: billingCycle,
            nextChargeDate: nextCharge ?? Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
            trialEndDate: trialEndDate,
            status: status
        )
    }

    // MARK: - cycleLabel

    @Test("cycleLabel maps all BillingCycle variants")
    func cycleLabelMapping() {
        #expect(RecurringItemFormatter.cycleLabel(for: .weekly) == .weekly)
        #expect(RecurringItemFormatter.cycleLabel(for: .monthly) == .monthly)
        #expect(RecurringItemFormatter.cycleLabel(for: .annual) == .yearly)

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .quarterly) {
            #expect(text == "кв")
        } else {
            Issue.record("Quarterly should produce .custom")
        }

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .semiannual) {
            #expect(text == "п/г")
        } else {
            Issue.record("Semiannual should produce .custom")
        }

        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .custom(days: 14)) {
            #expect(text == "14д")
        } else {
            Issue.record("Custom(14) should produce .custom")
        }
    }

    @Test("cycleLabel custom with 1 day")
    func cycleLabelSingleDay() {
        if case .custom(let text) = RecurringItemFormatter.cycleLabel(for: .custom(days: 1)) {
            #expect(text == "1д")
        } else {
            Issue.record("Custom(1) should produce .custom")
        }
    }

    // MARK: - badge

    @Test("badge returns correct type for each status")
    func badgeMapping() {
        let trial = makeItem(status: .trial,
                             trialEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now))
        #expect(RecurringItemFormatter.badge(for: trial) == .trial)

        let failed = makeItem(status: .failed)
        #expect(RecurringItemFormatter.badge(for: failed) == .failed)

        let paused = makeItem(status: .paused)
        #expect(RecurringItemFormatter.badge(for: paused) == .paused)

        let dueSoon = makeItem(status: .dueSoon)
        #expect(RecurringItemFormatter.badge(for: dueSoon) == .dueSoon)

        let dueToday = makeItem(status: .dueToday)
        #expect(RecurringItemFormatter.badge(for: dueToday) == .dueSoon)

        // Active monthly — no badge
        let active = makeItem(billingCycle: .monthly, status: .active)
        #expect(RecurringItemFormatter.badge(for: active) == nil)

        // Active annual — gets .annual badge
        let annual = makeItem(billingCycle: .annual, status: .active)
        #expect(RecurringItemFormatter.badge(for: annual) == .annual)
    }

    @Test("badge returns nil for cancelled items")
    func badgeCancelledNil() {
        let cancelled = makeItem(status: .cancelled)
        #expect(RecurringItemFormatter.badge(for: cancelled) == nil)
    }

    // MARK: - chargeSubtitle

    @Test("chargeSubtitle handles edge days correctly")
    func chargeSubtitleEdgeCases() {
        let cal = Calendar.current
        let todayNoon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: .now)!

        let today = makeItem(nextCharge: todayNoon)
        let todaySubtitle = RecurringItemFormatter.chargeSubtitle(for: today)
        #expect(!todaySubtitle.contains("Просрочено"))

        let overdue = makeItem(nextCharge: cal.date(byAdding: .day, value: -3, to: todayNoon))
        let subtitle = RecurringItemFormatter.chargeSubtitle(for: overdue)
        #expect(subtitle.contains("Просрочено"))

        let future = makeItem(nextCharge: cal.date(byAdding: .day, value: 10, to: todayNoon))
        let futureSubtitle = RecurringItemFormatter.chargeSubtitle(for: future)
        #expect(futureSubtitle.contains("Через"))
    }

    @Test("chargeSubtitle for tomorrow")
    func chargeSubtitleTomorrow() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now).addingTimeInterval(43200))!
        let item = makeItem(nextCharge: tomorrow)
        let subtitle = RecurringItemFormatter.chargeSubtitle(for: item)
        #expect(subtitle.contains("завтра") || subtitle.contains("Через"))
    }

    // MARK: - subtitle (full status handling)

    @Test("subtitle handles all statuses")
    func subtitleAllStatuses() {
        let cancelled = makeItem(status: .cancelled)
        #expect(RecurringItemFormatter.subtitle(for: cancelled) == "Отменена")

        let paused = makeItem(status: .paused)
        #expect(RecurringItemFormatter.subtitle(for: paused) == "На паузе")

        let archived = makeItem(status: .archived)
        #expect(RecurringItemFormatter.subtitle(for: archived) == "В архиве")

        let active = makeItem(status: .active)
        let activeSubtitle = RecurringItemFormatter.subtitle(for: active)
        #expect(!activeSubtitle.isEmpty)
    }

    // MARK: - trialSubtitle

    @Test("trialSubtitle handles nil and edge cases")
    func trialSubtitleEdgeCases() {
        let noTrial = makeItem(status: .active)
        #expect(RecurringItemFormatter.trialSubtitle(for: noTrial) == "Пробный период")

        let endingToday = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.startOfDay(for: .now)
        )
        let todaySubtitle = RecurringItemFormatter.trialSubtitle(for: endingToday)
        #expect(todaySubtitle.contains("Пробный период"))

        let manyDays = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 30, to: .now)
        )
        let manySubtitle = RecurringItemFormatter.trialSubtitle(for: manyDays)
        #expect(manySubtitle.contains("Осталось"))
        #expect(manySubtitle.contains("дн."))
    }

    @Test("trialSubtitle 1 day left")
    func trialSubtitleOneDay() {
        let item = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        )
        let subtitle = RecurringItemFormatter.trialSubtitle(for: item)
        #expect(subtitle.contains("1 день") || subtitle.contains("Пробный период"))
    }

    // MARK: - trialSeverity

    @Test("trialSeverity returns correct severity levels")
    func trialSeverityLevels() {
        let noTrial = makeItem()
        #expect(RecurringItemFormatter.trialSeverity(for: noTrial) == .info)

        let critical = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 1, to: .now)
        )
        #expect(RecurringItemFormatter.trialSeverity(for: critical) == .critical)

        let warning = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)
        )
        let warningSeverity = RecurringItemFormatter.trialSeverity(for: warning)
        #expect(warningSeverity == .warning || warningSeverity == .critical)

        let info = makeItem(
            status: .trial,
            trialEndDate: Calendar.current.date(byAdding: .day, value: 10, to: .now)
        )
        #expect(RecurringItemFormatter.trialSeverity(for: info) == .info)
    }

    // MARK: - pluralTrial

    @Test("pluralTrial follows Russian grammar rules")
    func pluralTrialRussian() {
        #expect(RecurringItemFormatter.pluralTrial(1) == "пробный")
        #expect(RecurringItemFormatter.pluralTrial(2) == "пробных")
        #expect(RecurringItemFormatter.pluralTrial(5) == "пробных")
        #expect(RecurringItemFormatter.pluralTrial(11) == "пробных")
        #expect(RecurringItemFormatter.pluralTrial(21) == "пробный")
        #expect(RecurringItemFormatter.pluralTrial(111) == "пробных")
    }
}

// MARK: - InsightsBuilder Tests

@Suite("InsightsBuilder")
struct InsightsBuilderTests {

    private func makeItem(
        status: ItemStatus = .active,
        daysOffset: Int = 3,
        amount: Decimal = 299
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            amount: amount,
            nextChargeDate: Calendar.current.date(byAdding: .day, value: daysOffset, to: .now)!,
            status: status
        )
    }

    @Test("Empty charges produce no insights")
    func emptyCharges() {
        let insights = InsightsBuilder.build(from: [])
        #expect(insights.isEmpty)
    }

    @Test("Overdue items produce critical insight")
    func overdueInsight() {
        let items = [
            makeItem(daysOffset: -2),
            makeItem(daysOffset: -5),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .critical && $0.title.contains("2") })
    }

    @Test("Failed items produce critical insight")
    func failedInsight() {
        let items = [
            makeItem(status: .failed, daysOffset: 1),
            makeItem(daysOffset: 3),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .critical && $0.title.contains("1") })
    }

    @Test("Multiple charges produce info insight")
    func multipleChargesInsight() {
        let items = [
            makeItem(daysOffset: 1, amount: 100),
            makeItem(daysOffset: 3, amount: 200),
        ]
        let insights = InsightsBuilder.build(from: items)
        #expect(insights.contains { $0.severity == .info && $0.title.contains("2") })
    }

    @Test("Single charge with no issues produces no insights")
    func singleNormalCharge() {
        let insights = InsightsBuilder.build(from: [makeItem()])
        #expect(insights.isEmpty)
    }
}
