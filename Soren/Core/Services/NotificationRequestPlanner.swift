import Foundation

enum NotificationRequestKind: String, Sendable, Equatable {
    case charge
    case trial
    case renewalDecision
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
    case projectionFailed(itemID: UUID, reason: RecurringScheduleProjectionError)
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

        for item in items {
            if let charge = planCharge(for: item, now: now, failures: &failures) {
                requests.append(charge)
            }
            if isEligible(item, at: now), let trial = planTrial(for: item, now: now) {
                requests.append(trial)
            }
            if let decision = planRenewalDecision(for: item, now: now, failures: &failures) {
                requests.append(decision)
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

        do {
            let projector = RecurringScheduleProjector()
            var lowerBound = try BillingCivilDay.civilDate(containing: now, in: calendar.timeZone)
            // Jump directly to today, never enumerate from the persisted anchor.
            // Only occurrences within the reminder-offset window can have a
            // missed fire time. Every subsequent query advances a civil day;
            // recurrence arithmetic and finite bounds remain owned by Domain.
            while let day = try projector.nextScheduledCharge(for: item, onOrAfter: lowerBound) {
                let occurrence = try BillingCivilDay.canonicalDate(for: day)
                guard let request = makeRequest(
                    item: item, kind: .charge, occurrence: occurrence, offsetDays: offsetDays
                ) else {
                    failures.append(.invalidDate(itemID: item.id))
                    return nil
                }
                if request.fireDate > now { return request }
                guard let nextDay = BillingCivilDay.calendar.date(byAdding: .day, value: 1, to: occurrence) else {
                    failures.append(.invalidDate(itemID: item.id))
                    return nil
                }
                lowerBound = try BillingCivilDay.civilDate(fromCanonicalDate: nextDay)
            }
        } catch let reason as RecurringScheduleProjectionError {
            failures.append(.projectionFailed(itemID: item.id, reason: reason))
        } catch {
            failures.append(.invalidDate(itemID: item.id))
        }
        return nil
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

    private func planRenewalDecision(
        for item: RecurringItem,
        now: Date,
        failures: inout [NotificationPlanningFailure]
    ) -> PlannedNotificationRequest? {
        guard item.renewalDecisionReminderEnabled, let deadline = item.renewalDecisionDeadline else { return nil }
        do {
            let today = try BillingCivilDay.civilDate(containing: now, in: calendar.timeZone)
            guard deadline >= today, try isDecisionEligible(item, deadline: deadline, today: today) else { return nil }
            let occurrence = try BillingCivilDay.canonicalDate(for: deadline)
            guard let request = makeRequest(item: item, kind: .renewalDecision, occurrence: occurrence, offsetDays: 0) else {
                failures.append(.invalidDate(itemID: item.id))
                return nil
            }
            return request.fireDate > now ? request : nil
        } catch {
            failures.append(.invalidDate(itemID: item.id))
            return nil
        }
    }

    private func isDecisionEligible(_ item: RecurringItem, deadline: CivilDate, today: CivilDate) throws -> Bool {
        guard item.archivedAt == nil else { return false }
        switch item.status {
        case .cancelled, .archived: return false
        case .active, .dueSoon, .dueToday, .overdue, .failed, .trial, .paused: break
        }
        guard !item.autoRenew else { return true }
        guard let endDate = item.endDate else { throw BillingCivilDayError.arithmeticFailed }
        let end = try BillingCivilDay.civilDate(fromCanonicalDate: endDate)
        return today <= end && deadline <= end
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

        if kind == .renewalDecision {
            let local = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            guard local.year == occurrenceDay.year, local.month == occurrenceDay.month,
                  local.day == occurrenceDay.day, local.hour == 9, local.minute == 0 else { return nil }
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
        case .renewalDecision:
            return PlannedNotificationRequest(
                id: identifier,
                itemID: item.id,
                kind: kind,
                occurrenceDate: occurrence,
                occurrenceLocalDateKey: occurrenceKey,
                reminderOffsetDays: offsetDays,
                fireDate: fireDate,
                trigger: trigger,
                title: String(localized: "notification.renewalDecision.title", bundle: bundle, locale: locale),
                body: String(
                    format: String(localized: "notification.renewalDecision.body", bundle: bundle, locale: locale),
                    locale: locale, date, item.title
                )
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
        guard item.archivedAt == nil,
              item.status != .paused, item.status != .cancelled, item.status != .archived else {
            return false
        }
        guard !item.autoRenew, let endDate = item.endDate else { return true }
        guard let end = try? BillingCivilDay.civilDate(fromCanonicalDate: endDate),
              let today = try? BillingCivilDay.civilDate(containing: now, in: calendar.timeZone) else { return false }
        return end >= today
    }
}
