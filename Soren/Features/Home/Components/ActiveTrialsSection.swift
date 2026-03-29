import SwiftUI

// MARK: - Active Trials Section

/// Dashboard section showing active trial periods with urgency indicators.
struct ActiveTrialsSection: View {
    let trials: [RecurringItem]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Пробные периоды")

            ForEach(trials) { trial in
                InsightCard(
                    icon: "clock.badge.exclamationmark",
                    title: trial.title,
                    subtitle: RecurringItemFormatter.trialSubtitle(for: trial),
                    severity: RecurringItemFormatter.trialSeverity(for: trial)
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActiveTrialsSection(
        trials: [
            RecurringItem(
                title: "Claude Pro",
                category: .aiTools,
                amount: 20,
                currencyCode: "USD",
                nextChargeDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)!,
                trialEndDate: Calendar.current.date(byAdding: .day, value: 3, to: .now)
            ),
        ]
    )
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
