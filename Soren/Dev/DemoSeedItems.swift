#if DEBUG
import Foundation

// MARK: - Demo Seed Items

/// Definitions for the 15-item App Store screenshot dataset.
///
/// All charge dates are computed as offsets from a caller-supplied reference date,
/// ensuring the Calendar, Alerts, and Analytics screens look fresh no matter
/// when the seed is applied.
///
/// Dataset summary (T = start of the reference day):
/// - Alerts richness: overdue (T−2), dueToday (T+0), dueSoon ×3 (T+1/+4/+5), trial (T+7)
/// - Currency mix: RUB ×5, USD ×7, EUR ×1, TRY ×1
/// - Analytics spike: NordVPN annual charge lands in next calendar month
/// - Unused flag: Notion carries `usageStatus: .unused`
enum DemoSeedItems {

    // MARK: - Factory

    static func items(
        relativeTo referenceDate: Date,
        calendar: Calendar = .current
    ) -> [RecurringItem] {

        let today = calendar.startOfDay(for: referenceDate)

        /// Offset `today` by `n` days (negative for past, positive for future).
        func days(_ n: Int) -> Date {
            calendar.date(byAdding: .day, value: n, to: today) ?? today
        }

        /// 14th day of the calendar month following the reference month.
        /// Guarantees NordVPN's annual renewal falls in the next month
        /// so the Analytics bar chart shows a visible spike.
        func nextMonthMid() -> Date {
            let comps = calendar.dateComponents([.year, .month], from: today)
            var nm = DateComponents()
            nm.year  = comps.year
            nm.month = (comps.month ?? 1) + 1
            nm.day   = 1
            let firstOfNext = calendar.date(from: nm) ?? today
            return calendar.date(byAdding: .day, value: 14, to: firstOfNext) ?? today
        }

        let tag = DemoDataSeeder.demoTag

        return [

            // ── 1. X Premium ─ overdue ─────────────────────────────────────────
            // Overdue item fills the critical "Просрочено" section in Alerts.
            // $8 USD · creators · charge was 2 days ago
            RecurringItem(
                title: "X Premium",
                providerID: "x_premium", providerName: "X Premium",
                category: .creators,
                amount: 8, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-60), nextChargeDate: days(-2),
                status: .overdue, usageStatus: .occasionallyUsed,
                tags: [tag]
            ),

            // ── 2. Boosty ─ due today ──────────────────────────────────────────
            // dueToday item fills the "Сегодня" Alerts section.
            // 299 ₽ · creators · charges today
            RecurringItem(
                title: "Boosty",
                providerID: "boosty", providerName: "Boosty",
                category: .creators,
                amount: 299, currencyCode: "RUB", billingCycle: .monthly,
                startDate: days(-120), nextChargeDate: today,
                status: .dueToday, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 3. YouTube Premium ─ due tomorrow (TRY) ───────────────────────
            // TRY currency; fills the "due tomorrow" slot in Alerts.
            // 89 ₺ · video · T+1
            RecurringItem(
                title: "YouTube Premium",
                providerID: "youtube_premium", providerName: "YouTube Premium",
                category: .video,
                amount: 89, currencyCode: "TRY", billingCycle: .monthly,
                startDate: days(-90), nextChargeDate: days(1),
                status: .dueSoon, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 4. Netflix ─ due in 4 days ─────────────────────────────────────
            // High-recognition logo; dueSoon fills Alerts "Скоро" section.
            // $19.99 USD · video · T+4
            RecurringItem(
                title: "Netflix",
                providerID: "netflix", providerName: "Netflix",
                category: .video,
                amount: Decimal(string: "19.99")!, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-45), nextChargeDate: days(4),
                status: .dueSoon, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 5. Telegram Premium ─ due in 5 days ───────────────────────────
            // Widely used in RU market; rounds out the Alerts "Скоро" section.
            // $4.99 USD · creators · T+5
            RecurringItem(
                title: "Telegram Premium",
                providerID: "telegram_premium", providerName: "Telegram Premium",
                category: .creators,
                amount: Decimal(string: "4.99")!, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-150), nextChargeDate: days(5),
                status: .dueSoon, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 6. ChatGPT Plus ─ active trial, ending in 7 days ──────────────
            // Fills the "Триал заканчивается" Alerts section.
            // trialEndDate == nextChargeDate so both show T+7.
            // $20 USD · aiTools · trial
            RecurringItem(
                title: "ChatGPT Plus",
                providerID: "chatgpt_plus", providerName: "ChatGPT Plus",
                category: .aiTools,
                amount: 20, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-14), nextChargeDate: days(7),
                trialEndDate: days(7),
                status: .trial, usageStatus: .unknown,
                tags: [tag]
            ),

            // ── 7. Яндекс Диск 1 ТБ ─ active ─────────────────────────────────
            // RUB cloud storage; supports the cloud category in Analytics.
            // 249 ₽ · cloud · T+11
            RecurringItem(
                title: "Яндекс Диск",
                providerID: "yandex_disk", providerName: "Яндекс Диск",
                category: .cloud,
                amount: 249, currencyCode: "RUB", billingCycle: .monthly,
                startDate: days(-200), nextChargeDate: days(11),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 8. Кинопоиск ─ active ─────────────────────────────────────────
            // Russian video streaming; adds RUB to the video category.
            // 399 ₽ · video · T+13
            RecurringItem(
                title: "Кинопоиск",
                providerID: "kinopoisk", providerName: "Кинопоиск",
                category: .video,
                amount: 399, currencyCode: "RUB", billingCycle: .monthly,
                startDate: days(-180), nextChargeDate: days(13),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 9. iCloud+ 200 ГБ ─ active ────────────────────────────────────
            // Apple-native; familiar logo; sub-$3 shows price variety.
            // $2.99 USD · cloud · T+15
            RecurringItem(
                title: "iCloud+ 200 ГБ",
                providerID: "icloud", providerName: "iCloud+",
                category: .cloud,
                amount: Decimal(string: "2.99")!, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-365), nextChargeDate: days(15),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 10. Яндекс Плюс ─ active ──────────────────────────────────────
            // RU ecosystem bundle; dominant Russian service in the dataset.
            // 399 ₽ · shopping · T+17
            RecurringItem(
                title: "Яндекс Плюс",
                providerID: "yandex_plus", providerName: "Яндекс Плюс",
                category: .shopping,
                amount: 399, currencyCode: "RUB", billingCycle: .monthly,
                startDate: days(-300), nextChargeDate: days(17),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 11. МТС ─ active ───────────────────────────────────────────────
            // Russian mobile plan; large RUB amount looks good in Library totals.
            // 590 ₽ · mobile · T+19
            RecurringItem(
                title: "МТС",
                providerID: "mts", providerName: "МТС",
                category: .mobile,
                amount: 590, currencyCode: "RUB", billingCycle: .monthly,
                startDate: days(-730), nextChargeDate: days(19),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 12. Spotify ─ active (EUR) ─────────────────────────────────────
            // EUR currency; universally recognised logo; music category.
            // €12.99 EUR · music · T+21
            RecurringItem(
                title: "Spotify",
                providerID: "spotify", providerName: "Spotify",
                category: .music,
                amount: Decimal(string: "12.99")!, currencyCode: "EUR", billingCycle: .monthly,
                startDate: days(-240), nextChargeDate: days(21),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 13. GitHub Copilot ─ active ────────────────────────────────────
            // Developer tool; productivity category adds breadth to Analytics.
            // $10 USD · productivity · T+26
            RecurringItem(
                title: "GitHub Copilot",
                providerID: "github_copilot", providerName: "GitHub Copilot",
                category: .productivity,
                amount: 10, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-60), nextChargeDate: days(26),
                status: .active, usageStatus: .frequentlyUsed,
                tags: [tag]
            ),

            // ── 14. Notion ─ active, UNUSED ────────────────────────────────────
            // The classic "forgotten subscription" insight.
            // usageStatus: .unused surfaces in Analytics to demonstrate app value.
            // $16 USD · productivity · T+32
            RecurringItem(
                title: "Notion",
                providerID: "notion", providerName: "Notion",
                category: .productivity,
                amount: 16, currencyCode: "USD", billingCycle: .monthly,
                startDate: days(-90), nextChargeDate: days(32),
                status: .active, usageStatus: .unused,
                note: "Давно не открывал",
                tags: [tag]
            ),

            // ── 15. NordVPN ─ annual, active ───────────────────────────────────
            // The only annual item. Its full $59.88 charge lands in the next
            // calendar month, creating a visible spike in the Analytics bar chart.
            // $59.88 USD/year · vpn · nextMonthMid()
            RecurringItem(
                title: "NordVPN",
                providerID: "nordvpn", providerName: "NordVPN",
                category: .vpn,
                amount: Decimal(string: "59.88")!, currencyCode: "USD", billingCycle: .annual,
                startDate: days(-351), nextChargeDate: nextMonthMid(),
                status: .active, usageStatus: .occasionallyUsed,
                note: "Ежегодное продление",
                tags: [tag]
            ),
        ]
    }
}
#endif
