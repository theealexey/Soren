import Foundation
import UserNotifications

// MARK: - Notification Scheduling Protocol

/// Abstracts OS-level local notification scheduling.
/// ViewModels depend on this protocol — never on UserNotifications directly —
/// so the scheduler can be swapped for a mock in tests.
protocol NotificationScheduling: AnyObject, Sendable {

    /// Schedules (or reschedules) a charge reminder for the given item.
    /// Cancels any existing notification for the same item ID before adding the new one.
    /// Silently no-ops if the item is ineligible or the user has denied permission.
    func schedule(for item: RecurringItem) async

    /// Cancels any pending or delivered charge notification for the given item ID.
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
/// Identifier scheme (stable across reschedules):
///   `"soren.charge.<item-UUID>"`
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

        // User chose "Never" for this subscription — ensure no pending notification.
        guard let alertDays = item.chargeReminder.alertDays else {
            await cancel(for: item.id)
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

        // Remove the old request first so there is never a duplicate identifier
        // (adding a request with an existing identifier silently replaces it in
        //  UNUserNotificationCenter, but explicit removal keeps intent clear).
        center.removePendingNotificationRequests(withIdentifiers: [chargeIdentifier(for: item.id)])

        let content    = makeContent(item: item, chargeDate: chargeDate, chargeAlertDays: alertDays)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger    = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request    = UNNotificationRequest(
            identifier: chargeIdentifier(for: item.id),
            content:    content,
            trigger:    trigger
        )

        try? await center.add(request)
    }

    // MARK: - Cancel

    func cancel(for itemID: UUID) async {
        let id = chargeIdentifier(for: itemID)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
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

    /// Computes the 09:00 fire date for a charge reminder.
    ///
    /// Pure function — no side effects, no state read.
    /// `nonisolated static` so it can be called in tests without instantiating the scheduler.
    ///
    /// - Parameters:
    ///   - chargeDate:      The effective next charge date for the item.
    ///   - chargeAlertDays: How many days before the charge to fire.
    ///   - now:             Reference point for "is the candidate in the past?" (injectable for tests).
    ///   - calendar:        Calendar used for date arithmetic (injectable for tests).
    nonisolated static func computeFireDate(
        chargeDate:      Date,
        chargeAlertDays: Int,
        now:             Date = .now,
        calendar:        Calendar = .current
    ) -> Date {
        // Step 1 — compute the alert day: N days before the charge date.
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

    // MARK: - Content

    private func makeContent(item: RecurringItem, chargeDate: Date, chargeAlertDays: Int) -> UNMutableNotificationContent {
        let content   = UNMutableNotificationContent()
        content.title = notificationTitle(itemTitle: item.title, chargeAlertDays: chargeAlertDays)
        content.body  = notificationBody(amount: item.amount, currency: item.currencyCode, chargeDate: chargeDate)
        content.sound = .default
        return content
    }

    private func notificationTitle(itemTitle: String, chargeAlertDays: Int) -> String {
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

    private func notificationBody(amount: Decimal, currency: String, chargeDate: Date) -> String {
        let formatter                 = NumberFormatter()
        formatter.numberStyle         = .currency
        formatter.currencyCode        = currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let amountString = formatter.string(for: amount) ?? "\(amount)"
        let dateString   = chargeDate.formatted(.dateTime.day().month())
        return "\(amountString) · \(dateString)"
    }

    // MARK: - Russian day pluralization

    private func pluralDays(_ n: Int) -> String {
        let mod10  = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "\(n) день" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "\(n) дня" }
        return "\(n) дней"
    }

    // MARK: - Identifier

    private func chargeIdentifier(for itemID: UUID) -> String {
        "soren.charge.\(itemID.uuidString)"
    }
}
