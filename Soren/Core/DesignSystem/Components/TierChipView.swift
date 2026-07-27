import SwiftUI

// MARK: - Tier Chip View

enum TierChipPricingPresentation: Equatable {
    case verified(money: Money, billingCycle: BillingCycle)
    case requiresReview
    case manualEntry
}

/// Compact card for selecting a plan tier in the Add Subscription flow.
/// Shows tier name, formatted price with billing cycle, and optional features line.
///
/// Usage:
/// ```swift
/// TierChipView(tier: tier, pricingPresentation: .manualEntry, isSelected: true)
/// ```
struct TierChipView: View {
    let tier: PlanTier
    let pricingPresentation: TierChipPricingPresentation
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(localized(tier.name))
                .font(Typography.captionMedium)
                .foregroundStyle(isSelected ? .white : ColorTokens.textPrimary)

            switch pricingPresentation {
            case .verified(let money, let billingCycle):
                AmountLabel(
                    money.amount,
                    currency: money.currencyCode,
                    size: .small,
                    cycle: cycleLabel(for: billingCycle),
                    tint: isSelected ? .white : nil
                )

            case .requiresReview:
                Text(String(localized: "Проверьте цену"))
                    .font(Typography.caption)
                    .italic()
                    .foregroundStyle(isSelected ? .white.opacity(0.65) : ColorTokens.textTertiary)

            case .manualEntry:
                Text(String(localized: "Введите цену"))
                    .font(Typography.caption)
                    .italic()
                    .foregroundStyle(isSelected ? .white.opacity(0.65) : ColorTokens.textTertiary)
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

    private func cycleLabel(for billingCycle: BillingCycle) -> AmountLabel.CycleLabel {
        switch billingCycle {
        case .monthly: .monthly
        case .annual: .yearly
        case .weekly: .weekly
        default: .custom(billingCycle.shortName)
        }
    }

    private func localized(_ value: String) -> String {
        String(localized: String.LocalizationValue(value))
    }
}

// MARK: - Preview

#Preview {
    let tiers: [PlanTier] = [
        .init(id: "standard_ads", name: "Standard с рекламой", referenceAmount: 7.99, billingCycle: .monthly, features: "1080p, 2 экрана"),
        .init(id: "standard", name: "Standard", referenceAmount: 15.49, billingCycle: .monthly, features: "1080p, 2 экрана, скачивание"),
        .init(id: "premium", name: "Premium", referenceAmount: 22.99, billingCycle: .monthly, features: "4K HDR, 4 экрана"),
    ]

    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: Spacing.sm) {
            TierChipView(tier: tiers[0], pricingPresentation: .manualEntry, isSelected: false)
            TierChipView(tier: tiers[1], pricingPresentation: .requiresReview, isSelected: true)
            TierChipView(tier: tiers[2], pricingPresentation: .manualEntry, isSelected: false)
        }
        .padding(.horizontal, Spacing.lg)
    }
    .padding(.vertical, Spacing.lg)
    .background(ColorTokens.background)
}
