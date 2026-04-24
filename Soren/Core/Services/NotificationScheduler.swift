import Foundation
import UserNotifications

// MARK: - Notification Scheduling Protocol

/// Abstracts OS-level local notification scheduling.
/// ViewModels depend on this protocol — never on UserNotifications directly —
/// so the scheduler can be swapped for a mock in tests.
protocol NotificationScheduling: AnyObject, Sendable {

    /// Schedules (or reschedules) the reminders for the given item.
    /// Handles both the recurring charge reminder and the trial-ending reminder
    /// (when `trialEndDate` is set and the user opted in).
    /// Cancels any existing notification for the same item ID before adding new ones.
    /// Silently no-ops if the item is ineligible or the user has denied permission.
    func schedule(for item: RecurringItem) async

    /// Cancels any pending or delivered notifications (charge and trial) for the given item ID.
    func cancel(for itemID: UUID) async

    /// Cancels every pending and delivered notification issued by Soren.
    func cancelAll() async
}

// MARK: - Notification Scheduler

/// Concrete implementation backed by `UNUserNotificationCenter`.
///
/// Scheduling strategy for charge reminders:
///   • Fire at 09:00 on the day that is `item.chargeReminder.alertDays` before
///     `effectiveNextChargeDate`. If that date is already past, fire at the next
///     available 09:00 (today if before 09:00, tomorrow otherwise) — never silently
///     drop the notification.
///   • When `item.chargeReminder == .never`, any existing notification is cancelled.
///
/// Scheduling strategy for trial-ending reminders:
///   • Fires only when `trialEndDate != nil` and `trialReminder != .never`.
///   • Uses the same 09:00 fire-date logic relative to `trialEndDate`.
///
/// Identifier scheme (stable across reschedules):
///   `"soren.charge.<item-UUID>"` for charge reminders
///   `"soren.trial.<item-UUID>"`  for trial-ending reminders
final class NotificationScheduler: NotificationScheduling, @unchecked Sendable {

    // MARK: - Dependencies

    private let center: UNUserNotificationCenter
    private let calendar: Calendar

    // MARK: - Init

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    // MARK: - Schedule

    func schedule(for item: RecurringItem) async {
        guard isEligible(item) else {
            await cancel(for: item.id)
            return
        }

        await scheduleChargeReminder(for: item)
        await scheduleTrialReminder(for: item)
    }

    private func scheduleChargeReminder(for item: RecurringItem) async {
        let identifier = chargeIdentifier(for: item.id)

        // User chose "Never" for this subscription — ensure no pending notification.
        guard let alertDays = item.chargeReminder.alertDays else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            return
        }

        guard await requestAuthorizationIfNeeded() else { return }

        let chargeDate = item.effectiveNextChargeDate()
        let fireDate   = Self.computeFireDate(
            chargeDate:      chargeDate,
            chargeAlertDays: alertDays,
            now:             Date.now,
            calendar:        calendar
        )

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content    = makeChargeContent(item: item, chargeDate: chargeDate, chargeAlertDays: alertDays)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request    = UNNotificationRequest(
            identifier: identifier,
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    private func scheduleTrialReminder(for item: RecurringItem) async {
        let identifier = trialIdentifier(for: item.id)

        guard let trialEnd = item.trialEndDate,
              let alertDays = item.trialReminder.alertDays else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            return
        }

        guard await requestAuthorizationIfNeeded() else { return }

        let fireDate = Self.computeFireDate(
            chargeDate:      trialEnd,
            chargeAlertDays: alertDays,
            now:             Date.now,
            calendar:        calendar
        )

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content    = makeTrialContent(item: item, trialAlertDays: alertDays)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request    = UNNotificationRequest(
            identifier: identifier,
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel

    func cancel(for itemID: UUID) async {
        let ids = [chargeIdentifier(for: itemID), trialIdentifier(for: itemID)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func cancelAll() async {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Eligibility

    /// Returns `true` when the item should have a scheduled reminder.
    /// Internal (not private) so tests can verify the gate directly.
    func isEligible(_ item: RecurringItem) -> Bool {
        switch item.status {
        case .paused, .cancelled, .archived:
            return false
        default:
            break
        }
        return !item.isExpired
    }

    // MARK: - Fire Date

    /// Computes the 09:00 fire date for a charge or trial reminder.
    ///
    /// Pure function — no side effects, no state read.
    /// `nonisolated static` so it can be called in tests without instantiating the scheduler.
    ///
    /// The parameter names reference "charge" for historical reasons; the function is
    /// equally valid for trial-ending reminders when passed `chargeDate: trialEndDate`.
    ///
    /// - Parameters:
    ///   - chargeDate:      The effective next charge date (or trial-end date) for the item.
    ///   - chargeAlertDays: How many days before the target date to fire.
    ///   - now:             Reference point for "is the candidate in the past?" (injectable for tests).
    ///   - calendar:        Calendar used for date arithmetic (injectable for tests).
    nonisolated static func computeFireDate(
        chargeDate:      Date,
        chargeAlertDays: Int,
        now:             Date = .now,
        calendar:        Calendar = .current
    ) -> Date {
        // Step 1 — compute the alert day: N days before the target date.
        let alertDay = calendar.date(byAdding: .day, value: -chargeAlertDays, to: chargeDate) ?? chargeDate

        // Step 2 — target 09:00 on that day.
        var comps  = calendar.dateComponents([.year, .month, .day], from: alertDay)
        comps.hour = 9; comps.minute = 0; comps.second = 0
        let candidate = calendar.date(from: comps) ?? alertDay

        guard candidate <= now else { return candidate }

        // Step 3 — past: try today at 09:00.
        var todayComps  = calendar.dateComponents([.year, .month, .day], from: now)
        todayComps.hour = 9; todayComps.minute = 0; todayComps.second = 0
        let todayAt9 = calendar.date(from: todayComps) ?? now

        if todayAt9 > now { return todayAt9 }

        // Step 4 — today's 09:00 has already passed: use tomorrow at 09:00.
        return calendar.date(byAdding: .day, value: 1, to: todayAt9) ?? todayAt9
    }

    // MARK: - Permission

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Content (charge)

    private func makeChargeContent(item: RecurringItem, chargeDate: Date, chargeAlertDays: Int) -> UNMutableNotificationContent {
        let content   = UNMutableNotificationContent()
        content.title = chargeTitle(itemTitle: item.title, chargeAlertDays: chargeAlertDays)
        content.body  = chargeBody(amount: item.amount, currency: item.currencyCode, chargeDate: chargeDate)
        content.sound = .default
        return content
    }

    private func chargeTitle(itemTitle: String, chargeAlertDays: Int) -> String {
        switch chargeAlertDays {
        case 0:
            return String(localized: "«\(itemTitle)» списывается сегодня")
        case 1:
            return String(localized: "«\(itemTitle)» списывается завтра")
        default:
            let days = pluralDays(chargeAlertDays)
            return String(localized: "«\(itemTitle)» списывается через \(days)")
        }
    }

    private var currencyFormatters: [String: NumberFormatter] = [:]

    private func currencyFormatter(for code: String) -> NumberFormatter {
        if let cached = currencyFormatters[code] { return cached }
        let f = NumberFormatter()
        f.numberStyle         = .currency
        f.currencyCode        = code
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        currencyFormatters[code] = f
        return f
    }

    private func chargeBody(amount: Decimal, currency: String, chargeDate: Date) -> String {
        let formatter    = currencyFormatter(for: currency)
        let amountString = formatter.string(for: amount) ?? "\(amount)"
        let dateString   = chargeDate.formatted(.dateTime.day().month())
        return "\(amountString) · \(dateString)"
    }

    // MARK: - Content (trial)

    private func makeTrialContent(item: RecurringItem, trialAlertDays: Int) -> UNMutableNotificationContent {
        let content   = UNMutableNotificationContent()
        content.title = trialTitle(itemTitle: item.title, trialAlertDays: trialAlertDays)
        content.body  = String(localized: "Отмените, если не хотите списания")
        content.sound = .default
        return content
    }

    private func trialTitle(itemTitle: String, trialAlertDays: Int) -> String {
        switch trialAlertDays {
        case 0:
            return String(localized: "Пробный период «\(itemTitle)» заканчивается сегодня")
        case 1:
            return String(localized: "Пробный период «\(itemTitle)» заканчивается завтра")
        default:
            let days = pluralDays(trialAlertDays)
            return String(localized: "Пробный период «\(itemTitle)» заканчивается через \(days)")
        }
    }

    // MARK: - Russian day pluralization

    private func pluralDays(_ n: Int) -> String {
        let mod10  = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "\(n) день" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(n) дня" }
        return "\(n) дней"
    }

    // MARK: - Identifiers

    private func chargeIdentifier(for itemID: UUID) -> String {
        "soren.charge.\(itemID.uuidString)"
    }

    private func trialIdentifier(for itemID: UUID) -> String {
        "soren.trial.\(itemID.uuidString)"
    }
}
