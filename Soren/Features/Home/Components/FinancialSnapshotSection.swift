import SwiftUI

// MARK: - Financial Snapshot Section

/// Dashboard overview: monthly/yearly totals and active count chips.
struct FinancialSnapshotSection: View {
    let summary: DashboardSummary
    let defaultCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Обзор")

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: summary.monthlyTotal,
                        currency: defaultCurrency,
                        amountSize: .large
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: summary.yearlyProjection,
                        currency: defaultCurrency,
                        amountSize: .large
                    )
                }
            }

            HStack(spacing: Spacing.sm) {
                metricChip(
                    icon: "repeat",
                    value: "\(summary.activeItemCount)",
                    label: String(localized: "активных")
                )

                if summary.activeTrialCount > 0 {
                    metricChip(
                        icon: "clock",
                        value: "\(summary.activeTrialCount)",
                        label: HomeViewModel.pluralTrial(summary.activeTrialCount)
                    )
                }
            }
        }
    }

    // MARK: - Metric Chip

    private func metricChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(Typography.overline)
                .foregroundStyle(ColorTokens.accent)

            Text(value)
                .font(Typography.captionMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(label)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(ColorTokens.accent.opacity(0.1), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    FinancialSnapshotSection(
        summary: DashboardSummary(
            monthlyTotal: 4299,
            yearlyProjection: 51_588,
            activeItemCount: 12,
            activeTrialCount: 2
        ),
        defaultCurrency: "RUB"
    )
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
