import SwiftUI

// MARK: - Insight Card

/// Smart insight display for dashboard and alerts.
/// Shows actionable financial observations with icon and tint.
///
/// Usage:
/// ```swift
/// InsightCard(
///     icon: "exclamationmark.triangle",
///     title: "4 charges in next 6 days",
///     subtitle: "Total: ₽2,847",
///     severity: .warning
/// )
/// ```
struct InsightCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let severity: Severity

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        severity: Severity = .info
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.severity = severity
    }

    var body: some View {
        PremiumCard(.tinted(severity.color)) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(Typography.cardIcon)
                    .foregroundStyle(severity.color)
                    .frame(width: IconSize.cardIcon)

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(title)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(ColorTokens.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(Typography.chevron)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }
}

// MARK: - Severity

extension InsightCard {
    enum Severity {
        case info
        case warning
        case critical
        case positive

        var color: Color {
            switch self {
            case .info:     ColorTokens.info
            case .warning:  ColorTokens.warning
            case .critical: ColorTokens.error
            case .positive: ColorTokens.success
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.sm) {
        InsightCard(
            icon: "exclamationmark.triangle",
            title: "4 списания за 6 дней",
            subtitle: "Итого: ₽2 847",
            severity: .warning
        )

        InsightCard(
            icon: "arrow.up.right",
            title: "Расходы выросли на 12% за месяц",
            severity: .critical
        )

        InsightCard(
            icon: "arrow.down.right",
            title: "Сэкономлено ₽1 200 за месяц",
            severity: .positive
        )

        InsightCard(
            icon: "clock",
            title: "Яндекс Плюс: триал через 3 дня",
            subtitle: "Продление за ₽399/мес",
            severity: .info
        )
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
