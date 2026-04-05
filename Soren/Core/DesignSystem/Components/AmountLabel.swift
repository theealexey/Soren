import SwiftUI

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

    init(
        _ amount: Decimal,
        currency currencyCode: String = "RUB",
        size: Size = .medium,
        cycle: CycleLabel? = nil,
        tint: Color? = nil
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.size = size
        self.cycle = cycle
        self.tint = tint
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
            Text(formattedAmount)
                .font(size.font)
                .foregroundStyle(tint ?? ColorTokens.textPrimary)
                .contentTransition(.numericText(value: Double(truncating: amount as NSDecimalNumber)))

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
        let formatted = Self.formatter(for: currencyCode)
            .string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
        guard let cycle else { return formatted }
        return "\(formatted) \(cycle.accessibilityText)"
    }

    private var formattedAmount: String {
        Self.formatter(for: currencyCode).string(
            from: amount as NSDecimalNumber
        ) ?? "\(amount)"
    }

    /// Thread-safe formatter cache using nonisolated(unsafe) —
    /// AmountLabel is a View (always on @MainActor), so this is safe in practice.
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
