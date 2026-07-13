import SwiftUI

// MARK: - Tier Chip View

/// Compact card for selecting a plan tier in the Add Subscription flow.
/// Shows tier name, formatted price with billing cycle, and optional features line.
///
/// Usage:
/// ```swift
/// TierChipView(tier: tier, currencyCode: "USD", isSelected: true)
/// ```
struct TierChipView: View {
    let tier: PlanTier
    let currencyCode: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(localized(tier.name))
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? .white : ColorTokens.textPrimary)

            if tier.amount == 0 {
                // No reliable default price — prompt the user to enter their actual charge.
                Text(String(localized: "Введите цену"))
                    .font(Typography.caption)
                    .italic()
                    .foregroundStyle(isSelected ? .white.opacity(0.65) : ColorTokens.textTertiary)
            } else {
                AmountLabel(
                    tier.amount,
                    currency: tier.currencyCode ?? currencyCode,
                    size: .small,
                    cycle: cycleLabel,
                    tint: isSelected ? .white : nil
                )
            }

            if let features = tier.features {
                Text(localized(features))
                    .font(Typography.footnote)
                    .foregroundStyle(isSelected ? .white.opacity(0.7) : ColorTokens.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(minWidth: 100, alignment: .leading)
        .background(
            isSelected ? AnyShapeStyle(ColorTokens.accent) : AnyShapeStyle(ColorTokens.surfaceElevated),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(
                    isSelected ? .clear : ColorTokens.accent.opacity(0.3),
                    lineWidth: 1
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .animation(MotionTokens.snappy, value: isSelected)
    }

    private var cycleLabel: AmountLabel.CycleLabel {
        switch tier.billingCycle {
        case .monthly: .monthly
        case .annual: .yearly
        case .weekly: .weekly
        default: .custom(tier.billingCycle.shortName)
        }
    }

    private func localized(_ value: String) -> String {
        String(localized: String.LocalizationValue(value))
    }
}

// MARK: - Preview

#Preview {
    let tiers: [PlanTier] = [
        .init(id: "standard_ads", name: "Standard с рекламой", amount: 7.99, billingCycle: .monthly, features: "1080p, 2 экрана"),
        .init(id: "standard", name: "Standard", amount: 15.49, billingCycle: .monthly, features: "1080p, 2 экрана, скачивание"),
        .init(id: "premium", name: "Premium", amount: 22.99, billingCycle: .monthly, features: "4K HDR, 4 экрана"),
    ]

    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Spacing.sm) {
            TierChipView(tier: tiers[0], currencyCode: "USD", isSelected: false)
            TierChipView(tier: tiers[1], currencyCode: "USD", isSelected: true)
            TierChipView(tier: tiers[2], currencyCode: "USD", isSelected: false)
        }
        .padding(.horizontal, Spacing.lg)
    }
    .padding(.vertical, Spacing.lg)
    .background(ColorTokens.background)
}
