import SwiftUI

/// Opt-in formatting for normalized equivalents only. Stored and scheduled amounts keep their existing policy.
enum NormalizedMoneyFormatter {
    static func string(amount: Decimal, currencyCode: String,
                       locale: Locale = PresentationLocale.current,
                       style: NumberFormatter.Style = .currency) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.language.languageCode?.identifier == "ru" ? Locale(identifier: "ru") : locale
        formatter.numberStyle = style
        formatter.currencyCode = currencyCode
        let places = SupportedCurrency.all.first { $0.code == currencyCode }?.decimalPlaces
            ?? formatter.maximumFractionDigits
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = places
        formatter.roundingMode = .halfUp
        var source = amount
        var rounded = Decimal.zero
        NSDecimalRound(&rounded, &source, places, .plain)
        return formatter.string(from: rounded as NSDecimalNumber)
            ?? String(localized: "normalization.unavailable")
    }
}

// MARK: - Amount Label

/// Formatted currency display with consistent styling.
/// Single source of truth for how money values appear in the app.
///
/// Usage:
/// ```swift
/// AmountLabel(1247.99, currency: "RUB", size: .hero)
/// AmountLabel(12.99, currency: "USD", size: .medium, cycle: .monthly)
/// ```
struct AmountLabel: View {
    let amount: Decimal
    let currencyCode: String
    let size: Size
    let cycle: CycleLabel?
    let tint: Color?
    let normalized: Bool

    init(
        _ amount: Decimal,
        currency currencyCode: String = "RUB",
        size: Size = .medium,
        cycle: CycleLabel? = nil,
        tint: Color? = nil,
        normalized: Bool = false
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.size = size
        self.cycle = cycle
        self.tint = tint
        self.normalized = normalized
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxxs) {
            Text(formattedAmount)
                .font(size.font)
                .foregroundStyle(tint ?? ColorTokens.textPrimary)
                .contentTransition(.numericText(value: Double(truncating: amount as NSDecimalNumber)))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)

            if let cycle {
                Text(cycle.label)
                    .font(size.cycleFont)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let formatted = normalized ? NormalizedMoneyFormatter.string(amount: amount, currencyCode: currencyCode)
            : Self.formatter(for: currencyCode).string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
        guard let cycle else { return formatted }
        return "\(formatted) \(cycle.accessibilityText)"
    }

    var formattedAmount: String {
        let formatted = normalized ? NormalizedMoneyFormatter.string(amount: amount, currencyCode: currencyCode)
            : Self.formatter(for: currencyCode).string(
            from: amount as NSDecimalNumber
        ) ?? "\(amount)"
        // NumberFormatter inserts a non-breaking space between value and
        // currency symbol for many locale/currency pairs (e.g. "0,99 $").
        // A narrow no-break space keeps the pair from wrapping while
        // tightening the visual gap.
        return formatted.replacingOccurrences(of: "\u{00A0}", with: "\u{202F}")
    }

    /// Formatter cache isolated to `@MainActor` — AmountLabel is a View
    /// (always on @MainActor), so cache access is never concurrent.
    @MainActor
    private static var formatterCache: [String: NumberFormatter] = [:]

    @MainActor
    private static func formatter(for currencyCode: String) -> NumberFormatter {
        if let cached = formatterCache[currencyCode] { return cached }
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currencyCode
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        formatterCache[currencyCode] = fmt
        return fmt
    }
}

// MARK: - Size

extension AmountLabel {
    enum Size {
        /// 34pt — dashboard hero number.
        case hero
        /// 24pt — stat block, card amount.
        case large
        /// 17pt — list row, detail field.
        case medium
        /// 13pt — secondary amount, caption.
        case small

        var font: Font {
            switch self {
            case .hero:  Typography.heroAmount
            case .large: Typography.amountLarge
            case .medium: Typography.amountMedium
            case .small: Typography.amountSmall
            }
        }

        var cycleFont: Font {
            switch self {
            case .hero:  Typography.body
            case .large: Typography.caption
            case .medium: Typography.caption
            case .small: Typography.footnote
            }
        }
    }
}

// MARK: - Cycle Label

extension AmountLabel {
    enum CycleLabel: Equatable {
        case monthly
        case yearly
        case weekly
        case custom(String)

        /// Short visual suffix: "/мес", "/год", etc.
        var label: String {
            switch self {
            case .monthly:          String(localized: "/мес")
            case .yearly:           String(localized: "/год")
            case .weekly:           String(localized: "/нед")
            case .custom(let text): "/\(text)"
            }
        }

        /// Spoken version for VoiceOver: "в месяц", "в год", etc.
        var accessibilityText: String {
            switch self {
            case .monthly:          String(localized: "в месяц")
            case .yearly:           String(localized: "в год")
            case .weekly:           String(localized: "в неделю")
            case .custom(let text): text
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        AmountLabel(71_247.99, currency: "RUB", size: .hero)
        AmountLabel(249.50, currency: "RUB", size: .large, cycle: .monthly)
        AmountLabel(12.99, currency: "USD", size: .medium, cycle: .monthly)
        AmountLabel(0.99, currency: "USD", size: .small, cycle: .weekly)
        AmountLabel(1499, currency: "RUB", size: .medium, cycle: .monthly, tint: ColorTokens.error)
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
