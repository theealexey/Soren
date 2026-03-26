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
    let title: String
    let amount: Decimal
    let currencyCode: String
    let trend: Trend?
    let amountSize: AmountLabel.Size

    init(
        title: String,
        amount: Decimal,
        currency currencyCode: String = "RUB",
        trend: Trend? = nil,
        amountSize: AmountLabel.Size = .large
    ) {
        self.title = title
        self.amount = amount
        self.currencyCode = currencyCode
        self.trend = trend
        self.amountSize = amountSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .overlineStyle()

            AmountLabel(amount, currency: currencyCode, size: amountSize)

            if let trend {
                TrendBadge(trend: trend)
            }
        }
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
                .font(.system(size: 9, weight: .bold))

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
                title: "Monthly",
                amount: 4299,
                currency: "RUB",
                trend: .up(12.5)
            )
        }

        PremiumCard(.elevated) {
            StatBlock(
                title: "Yearly",
                amount: 51_588,
                currency: "RUB",
                trend: .down(3)
            )
        }
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
