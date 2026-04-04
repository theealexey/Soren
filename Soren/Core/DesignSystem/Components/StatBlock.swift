import SwiftUI

// MARK: - Stat Block

/// Financial metric display for dashboards.
/// Shows a label, a hero number, and optional trend indicator.
///
/// Usage:
/// ```swift
/// StatBlock(
///     title: "Monthly",
///     amount: 4299,
///     currency: "RUB",
///     trend: .up(12.5)
/// )
/// ```
struct StatBlock: View {
    let title: LocalizedStringKey
    let amount: Decimal
    let currencyCode: String
    let trend: Trend?
    let amountSize: AmountLabel.Size
    /// When true, the currency symbol is rendered on its own line below the amount.
    /// Useful for dashboard cards where visual alignment matters more than compactness.
    let breakCurrency: Bool

    init(
        title: LocalizedStringKey,
        amount: Decimal,
        currency currencyCode: String = "RUB",
        trend: Trend? = nil,
        amountSize: AmountLabel.Size = .large,
        breakCurrency: Bool = false
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.trend = trend
        self.amountSize = amountSize
        self.breakCurrency = breakCurrency
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .overlineStyle()

            if breakCurrency {
                VStack(alignment: .leading, spacing: 0) {
                    Text(formattedNumber)
                        .font(amountSize.font)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .contentTransition(.numericText(value: Double(truncating: amount as NSDecimalNumber)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(currencySymbol)
                        .font(amountSize.font)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
            } else {
                AmountLabel(amount, currency: currencyCode, size: amountSize)
            }

            if let trend {
                TrendBadge(trend: trend)
            }
        }
    }

    @MainActor
    private var formattedNumber: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.minimumFractionDigits = 0
        fmt.maximumFractionDigits = 2
        return fmt.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    @MainActor
    private var currencySymbol: String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .currency
        fmt.currencyCode = currencyCode
        return fmt.currencySymbol ?? currencyCode
    }
}

// MARK: - Trend

extension StatBlock {
    enum Trend {
        /// Spending increased by percentage.
        case up(Double)
        /// Spending decreased by percentage.
        case down(Double)
        /// No change.
        case flat
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let trend: StatBlock.Trend

    var body: some View {
        HStack(spacing: Spacing.xxxs) {
            Image(systemName: iconName)
                .font(Typography.trendBadge)

            Text(label)
                .font(Typography.footnote)
        }
        .foregroundStyle(tintColor)
    }

    private var iconName: String {
        switch trend {
        case .up:   "arrow.up.right"
        case .down: "arrow.down.right"
        case .flat: "arrow.right"
        }
    }

    private var label: String {
        switch trend {
        case .up(let pct):   "+\(formatted(pct))%"
        case .down(let pct): "-\(formatted(pct))%"
        case .flat:          "0%"
        }
    }

    private var tintColor: Color {
        switch trend {
        case .up:   ColorTokens.error  // spending up = bad
        case .down: ColorTokens.success // spending down = good
        case .flat: ColorTokens.textTertiary
        }
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: Spacing.md) {
        PremiumCard(.elevated) {
            StatBlock(
                title: "В месяц",
                amount: 4299,
                currency: "RUB",
                trend: .up(12.5)
            )
        }

        PremiumCard(.elevated) {
            StatBlock(
                title: "В год",
                amount: 51_588,
                currency: "RUB",
                trend: .down(3)
            )
        }
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
