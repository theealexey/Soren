import Foundation

/// Presentation-ready content for the single Overview Insight Stage.
///
/// Domain selection and financial calculations are completed before this
/// boundary. This type owns only localization and formatting for Home.
struct OverviewInsightPresentation: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case annualScale
        case denseWeek
        case trialAttention
        case sameDayAttention
    }

    enum PrimaryStyle: Equatable, Sendable {
        case financialValue
        case statement
    }

    let kind: Kind
    let eyebrow: String
    let primary: String
    let supporting: String
    let primaryStyle: PrimaryStyle
    let accessibilityLabel: String
}

/// The single money-formatting policy for production Overview presentation.
///
/// Russian app copy follows Russian financial grouping independently of the
/// device region. Other app languages retain the resolved regional currency
/// conventions supplied by `PresentationLocale`.
enum OverviewMoneyFormatter {
    static func string(
        _ money: Money,
        locale: Locale = PresentationLocale.current
    ) -> String {
        string(
            amount: money.amount,
            currencyCode: money.currencyCode,
            locale: locale
        )
    }

    static func string(
        amount: Decimal,
        currencyCode: String,
        locale: Locale = PresentationLocale.current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = monetaryLocale(for: locale)
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(amount) \(currencyCode)"
    }

    private static func monetaryLocale(for locale: Locale) -> Locale {
        guard locale.language.languageCode?.identifier == "ru" else {
            return locale
        }
        return Locale(identifier: "ru")
    }
}

extension OverviewInsightPresentation {
    static func make(
        from insight: OverviewInsight,
        today: Date,
        calendar: Calendar,
        locale: Locale = PresentationLocale.current
    ) -> Self {
        switch insight {
        case let .annualScale(total):
            return presentation(
                kind: .annualScale,
                eyebrow: String(localized: "ГОДОВОЙ МАСШТАБ"),
                primary: OverviewMoneyFormatter.string(total, locale: locale),
                supporting: String(localized: "при текущем наборе подписок"),
                primaryStyle: .financialValue
            )

        case let .denseWeek(denseWeek):
            let range = formattedDateRange(
                from: denseWeek.firstChargeDate,
                to: denseWeek.lastChargeDate,
                calendar: calendar,
                locale: locale
            )
            let supporting = denseWeek.total.map {
                "\(OverviewMoneyFormatter.string($0, locale: locale)) · \(range)"
            } ?? range

            return presentation(
                kind: .denseWeek,
                eyebrow: String(localized: "ПЛОТНАЯ НЕДЕЛЯ"),
                primary: String(localized: "\(denseWeek.chargeCount) списаний за 7 дней"),
                supporting: supporting,
                primaryStyle: .statement
            )

        case let .attention(.trialEnding(trial)):
            let primary = trialEndingPrimary(
                endDate: trial.trialEndDate,
                today: today,
                calendar: calendar
            )
            let supporting = trial.renewalTerms.map { terms in
                let amount = OverviewMoneyFormatter.string(terms.amount, locale: locale)
                let cycle = formatted(terms.billingCycle)
                return "\(trial.itemTitle) · \(String(localized: "затем")) \(amount) \(cycle)"
            } ?? trial.itemTitle

            return presentation(
                kind: .trialAttention,
                eyebrow: String(localized: "НА КОНТРОЛЕ"),
                primary: primary,
                supporting: supporting,
                primaryStyle: .statement
            )

        case let .attention(.sameDayRenewals(sameDay)):
            let date = formattedDate(
                sameDay.chargeDate,
                calendar: calendar,
                locale: locale
            )
            let supporting = sameDay.total.map {
                "\(date) · \(OverviewMoneyFormatter.string($0, locale: locale))"
            } ?? date

            return presentation(
                kind: .sameDayAttention,
                eyebrow: String(localized: "НА КОНТРОЛЕ"),
                primary: String(localized: "\(sameDay.chargeCount) списаний в один день"),
                supporting: supporting,
                primaryStyle: .statement
            )
        }
    }
}

private extension OverviewInsightPresentation {
    static func presentation(
        kind: Kind,
        eyebrow: String,
        primary: String,
        supporting: String,
        primaryStyle: PrimaryStyle
    ) -> Self {
        Self(
            kind: kind,
            eyebrow: eyebrow,
            primary: primary,
            supporting: supporting,
            primaryStyle: primaryStyle,
            accessibilityLabel: [eyebrow, primary, supporting].joined(separator: ". ")
        )
    }

    static func trialEndingPrimary(
        endDate: Date,
        today: Date,
        calendar: Calendar
    ) -> String {
        let todayStart = calendar.startOfDay(for: today)
        let endStart = calendar.startOfDay(for: endDate)
        let days = max(
            0,
            calendar.dateComponents([.day], from: todayStart, to: endStart).day ?? 0
        )

        switch days {
        case 0:
            return String(localized: "Пробный период заканчивается сегодня")
        case 1:
            return String(localized: "Пробный период заканчивается завтра")
        default:
            return String(localized: "Пробный период заканчивается через \(days) дней")
        }
    }

    static func formattedDate(
        _ date: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        let formatter = PresentationLocale.dateFormatter(
            template: "dMMMM",
            locale: locale,
            calendar: calendar
        )
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    static func formattedDateRange(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar,
        locale: Locale
    ) -> String {
        guard !calendar.isDate(startDate, inSameDayAs: endDate) else {
            return formattedDate(startDate, calendar: calendar, locale: locale)
        }

        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = "dMMMM"
        return formatter.string(from: startDate, to: endDate)
    }

    static func formatted(_ billingCycle: BillingCycle) -> String {
        switch billingCycle {
        case .weekly:
            return String(localized: "/нед")
        case .monthly:
            return String(localized: "/мес")
        case .quarterly:
            return String(localized: "/3 мес.")
        case .semiannual:
            return String(localized: "/6 мес.")
        case .annual:
            return String(localized: "/год")
        case let .custom(days):
            return String(localized: "каждые \(days) дней")
        }
    }
}
