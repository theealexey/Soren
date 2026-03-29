import SwiftUI

// MARK: - Financial Snapshot Section

/// Dashboard overview: monthly/yearly totals and active count chips.
struct FinancialSnapshotSection: View {
    let summary: DashboardSummary
    let defaultCurrency: String
    var ratesLastUpdated: Date?
    var isRatesStale: Bool = false

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
                        label: RecurringItemFormatter.pluralTrial(summary.activeTrialCount)
                    )
                }

                if summary.containsMixedCurrencies, ratesLastUpdated != nil {
                    metricChip(
                        icon: isRatesStale ? "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90" : "arrow.trianglehead.2.clockwise.rotate.90",
                        value: "",
                        label: ratesStatusLabel
                    )
                }
            }
        }
    }

    private var ratesStatusLabel: String {
        guard let date = ratesLastUpdated else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    // MARK: - Metric Chip

    private func metricChip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ColorTokens.accent)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(ColorTokens.textPrimary)

            Text(label)
                .font(.caption)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .lineLimit(1)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(ColorTokens.accent.opacity(0.1), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    FinancialSnapshotSection(
        summary: DashboardSummary(
            monthlyTotal: 4299,
            yearlyProjection: 51_588,
            activeItemCount: 12,
            activeTrialCount: 2,
            containsMixedCurrencies: true,
            ratesAvailable: true
        ),
        defaultCurrency: "RUB",
        ratesLastUpdated: Date().addingTimeInterval(-3600),
        isRatesStale: false
    )
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
