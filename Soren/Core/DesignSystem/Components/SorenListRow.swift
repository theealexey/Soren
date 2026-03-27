import SwiftUI

// MARK: - Soren List Row

/// Universal row for subscription/payment lists.
/// Used across Home (upcoming), Library, Search results, Alerts.
///
/// Displays: icon/logo → title + subtitle → amount + cycle badge.
///
/// Usage:
/// ```swift
/// SorenListRow(
///     title: "YouTube Premium",
///     subtitle: "Next charge: Apr 12",
///     amount: 299,
///     currency: "RUB",
///     cycle: .monthly,
///     iconName: "play.rectangle.fill",
///     iconColor: .red
/// )
/// ```
struct SorenListRow: View {
    let title: String
    let subtitle: String?
    let amount: Decimal
    let currencyCode: String
    let cycle: AmountLabel.CycleLabel?
    let iconName: String
    let iconColor: Color
    let badge: Badge?

    init(
        title: String,
        subtitle: String? = nil,
        amount: Decimal,
        currency currencyCode: String = "RUB",
        cycle: AmountLabel.CycleLabel? = .monthly,
        iconName: String = "app.fill",
        iconColor: Color = ColorTokens.accent,
        badge: Badge? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.currencyCode = currencyCode
        self.cycle = cycle
        self.iconName = iconName
        self.iconColor = iconColor
        self.badge = badge
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            iconView

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)

                    if let badge {
                        BadgeView(badge: badge)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            AmountLabel(amount, currency: currencyCode, size: .medium, cycle: cycle)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }

    private var iconView: some View {
        Image(systemName: iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(iconColor.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Badge

extension SorenListRow {
    enum Badge: Equatable {
        case trial
        case dueSoon
        case failed
        case paused
        case annual

        var title: String {
            switch self {
            case .trial:   "Пробный"
            case .dueSoon: "Скоро"
            case .failed:  "Ошибка"
            case .paused:  "Пауза"
            case .annual:  "Годовая"
            }
        }

        var color: Color {
            switch self {
            case .trial:   ColorTokens.warning
            case .dueSoon: ColorTokens.info
            case .failed:  ColorTokens.error
            case .paused:  ColorTokens.textTertiary
            case .annual:  ColorTokens.accent
            }
        }
    }
}

// MARK: - Badge View

private struct BadgeView: View {
    let badge: SorenListRow.Badge

    var body: some View {
        Text(badge.title)
            .font(Typography.footnote)
            .fontWeight(.medium)
            .foregroundStyle(badge.color)
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxxs)
            .background(badge.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SorenListRow(
            title: "YouTube Premium",
            subtitle: "Next charge: Apr 12",
            amount: 299,
            currency: "RUB",
            iconName: "play.rectangle.fill",
            iconColor: ColorTokens.categoryVideo
        )

        Divider().padding(.leading, 52 + Spacing.sm)

        SorenListRow(
            title: "Яндекс Плюс",
            subtitle: "Trial ends in 3 days",
            amount: 399,
            currency: "RUB",
            iconName: "star.fill",
            iconColor: .purple,
            badge: .trial
        )

        Divider().padding(.leading, 52 + Spacing.sm)

        SorenListRow(
            title: "iCloud+ 200GB",
            subtitle: "Charged monthly",
            amount: 2.99,
            currency: "USD",
            iconName: "icloud.fill",
            iconColor: ColorTokens.categoryCloud,
            badge: .annual
        )
    }
    .padding(.horizontal, Spacing.lg)
    .background(ColorTokens.background)
}
