import Foundation

enum NotificationRequestKind: String, Sendable, Equatable {
    case charge
    case trial
}

struct NotificationTriggerPlan: Sendable, Equatable {
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let timeZoneIdentifier: String
    let repeats: Bool
}

struct PlannedNotificationRequest: Sendable, Equatable, Identifiable {
    let id: String
    let itemID: UUID
    let kind: NotificationRequestKind
    let occurrenceDate: Date
    let occurrenceLocalDateKey: String
    let reminderOffsetDays: Int
    let fireDate: Date
    let trigger: NotificationTriggerPlan
    let title: String
    let body: String
}

enum NotificationPlanningFailure: Sendable, Equatable {
    case recurrenceDidNotAdvance(itemID: UUID)
    case recurrenceLimitExceeded(itemID: UUID)
    case invalidDate(itemID: UUID)
}

struct NotificationRequestPlan: Sendable, Equatable {
    let requests: [PlannedNotificationRequest]
    let failures: [NotificationPlanningFailure]
}

/// Builds the complete, app-owned desired notification state without accessing
/// persistence or UserNotifications. Injecting calendar, time zone and locale
/// makes wall-clock scheduling deterministic and independently testable.
struct NotificationRequestPlanner {
    private let calendar: Calendar
    private let locale: Locale
    private let bundle: Bundle

    init(calendar: Calendar, locale: Locale, bundle: Bundle = .main) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        self.calendar = gregorian
        self.locale = locale
        self.bundle = bundle
    }

    func plan(items: [RecurringItem], now: Date) -> NotificationRequestPlan {
        var requests: [PlannedNotificationRequest] = []
        var failures: [NotificationPlanningFailure] = []

        for item in items where isEligible(item, at: now) {
            if let charge = planCharge(for: item, now: now, failures: &failures) {
                requests.append(charge)
            }
            if let trial = planTrial(for: item, now: now) {
                requests.append(trial)
            }
        }

        return NotificationRequestPlan(requests: requests, failures: failures)
    }

    private func planCharge(
        for item: RecurringItem,
        now: Date,
        failures: inout [NotificationPlanningFailure]
    ) -> PlannedNotificationRequest? {
        guard let offsetDays = item.chargeReminder.alertDays else { return nil }

        var occurrence = item.nextChargeDate
        var iterations = 0

        while true {
            guard let request = makeRequest(
                item: item,
                kind: .charge,
                occurrence: occurrence,
                offsetDays: offsetDays
            ) else {
                failures.append(.invalidDate(itemID: item.id))
                return nil
            }

            if request.fireDate > now {
                return request
            }

            guard item.autoRenew else { return nil }
            guard iterations < 1_000 else {
                failures.append(.recurrenceLimitExceeded(itemID: item.id))
                return nil
            }

            let next = item.billingCycle.nextDate(after: occurrence, calendar: BillingCivilDay.calendar)
            guard next > occurrence else {
                failures.append(.recurrenceDidNotAdvance(itemID: item.id))
                return nil
            }
            occurrence = next
            iterations += 1
        }
    }

    private func planTrial(for item: RecurringItem, now: Date) -> PlannedNotificationRequest? {
        guard
            let trialEndDate = item.trialEndDate,
            let offsetDays = item.trialReminder.alertDays
        else {
            return nil
        }

        return makeRequest(
            item: item,
            kind: .trial,
            occurrence: trialEndDate,
            offsetDays: offsetDays
        ).flatMap { $0.fireDate > now ? $0 : nil }
    }

    private func makeRequest(
        item: RecurringItem,
        kind: NotificationRequestKind,
        occurrence: Date,
        offsetDays: Int
    ) -> PlannedNotificationRequest? {
        guard
            let occurrenceDay = try? BillingCivilDay.civilDate(fromCanonicalDate: occurrence),
            let canonicalReminderDay = BillingCivilDay.calendar.date(byAdding: .day, value: -offsetDays, to: occurrence),
            let reminderCivilDay = try? BillingCivilDay.civilDate(fromCanonicalDate: canonicalReminderDay),
            let reminderDay = calendar.date(from: DateComponents(
                year: reminderCivilDay.year, month: reminderCivilDay.month, day: reminderCivilDay.day, hour: 12
            )),
            let fireDate = calendar.date(
                bySettingHour: 9,
                minute: 0,
                second: 0,
                of: reminderDay,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        else {
            return nil
        }

        let occurrenceKey = String(format: "%04d%02d%02d", locale: Locale(identifier: "en_US_POSIX"),
                                   occurrenceDay.year, occurrenceDay.month, occurrenceDay.day)
        let components = calendar.dateComponents([.year, .month, .day], from: fireDate)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return nil
        }

        let identifier = "soren.v2.\(kind.rawValue).\(item.id.uuidString.lowercased()).\(occurrenceKey).\(offsetDays)"
        var style = Date.FormatStyle.dateTime.day().month(.wide).year().locale(locale)
        style.timeZone = .gmt
        style.calendar = BillingCivilDay.calendar
        let date = occurrence.formatted(style)
        let trigger = NotificationTriggerPlan(
            year: year,
            month: month,
            day: day,
            hour: 9,
            minute: 0,
            timeZoneIdentifier: calendar.timeZone.identifier,
            repeats: false
        )

        switch kind {
        case .charge:
            return PlannedNotificationRequest(
                id: identifier,
                itemID: item.id,
                kind: kind,
                occurrenceDate: occurrence,
                occurrenceLocalDateKey: occurrenceKey,
                reminderOffsetDays: offsetDays,
                fireDate: fireDate,
                trigger: trigger,
                title: String(
                    localized: "Ожидаемое списание: \(item.title)",
                    bundle: bundle,
                    locale: locale
                ),
                body: "\(date) · \(formattedAmount(for: item))"
            )
        case .trial:
            return PlannedNotificationRequest(
                id: identifier,
                itemID: item.id,
                kind: kind,
                occurrenceDate: occurrence,
                occurrenceLocalDateKey: occurrenceKey,
                reminderOffsetDays: offsetDays,
                fireDate: fireDate,
                trigger: trigger,
                title: String(
                    localized: "Пробный период заканчивается: \(item.title)",
                    bundle: bundle,
                    locale: locale
                ),
                body: date
            )
        }
    }

    private func formattedAmount(for item: RecurringItem) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = item.currencyCode
        return formatter.string(from: item.amount as NSDecimalNumber) ?? item.currencyCode
    }

    private func isEligible(_ item: RecurringItem, at now: Date) -> Bool {
        guard item.status != .paused, item.status != .cancelled, item.status != .archived else {
            return false
        }
        guard !item.autoRenew, let endDate = item.endDate else { return true }
        guard let end = try? BillingCivilDay.civilDate(fromCanonicalDate: endDate),
              let today = try? BillingCivilDay.civilDate(containing: now, in: calendar.timeZone) else { return false }
        return end >= today
    }
}
