import SwiftUI

// MARK: - Upcoming Charges Section View

/// "Ближайшие списания" — the next active recurring charges, soonest first.
///
/// Reuses `SorenListRow` so rows match Library, Search, and Alerts. Formatting
/// (cycle suffix, relative due date) comes from `RecurringItemFormatter` —
/// no billing logic is duplicated here. Shows a calm empty state when the
/// caller passes no items.
struct UpcomingChargesSectionView: View {

    let items: [RecurringItem]

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Ближайшие списания")
                .padding(.horizontal, Spacing.lg)

            if items.isEmpty {
                emptyState
            } else {
                rows
            }
        }
    }

    // MARK: - Rows

    private var rows: some View {
        VStack(spacing: 0) {
            hairline

            ForEach(items) { item in
                SorenListRow(
                    title: item.title,
                    subtitle: RecurringItemFormatter.chargeSubtitle(for: item),
                    amount: item.amount,
                    currency: item.currencyCode,
                    cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                    providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                    category: item.category
                )
                .padding(.horizontal, Spacing.lg)

                if item.id != items.last?.id {
                    hairline
                        .padding(.horizontal, Spacing.lg)
                }
            }

            hairline
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text("Нет ближайших списаний")
            .font(Typography.caption)
            .foregroundStyle(theme.tertiaryText)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
    }

    // MARK: - Hairline

    private var hairline: some View {
        Rectangle()
            .fill(theme.hairline)
            .frame(height: 1)
    }
}

// MARK: - Preview

#Preview("With items") {
    let now = Date.now
    let cal = Calendar.current

    return ScrollView {
        UpcomingChargesSectionView(items: [
            RecurringItem(
                title: "YouTube Premium",
                providerID: "youtube_premium",
                category: .video,
                amount: 299,
                currencyCode: "RUB",
                billingCycle: .monthly,
                nextChargeDate: cal.date(byAdding: .day, value: 1, to: now)!
            ),
            RecurringItem(
                title: "iCloud+ 200GB",
                category: .cloud,
                amount: 2.99,
                currencyCode: "USD",
                billingCycle: .monthly,
                nextChargeDate: cal.date(byAdding: .day, value: 4, to: now)!
            ),
            RecurringItem(
                title: "NordVPN",
                category: .other,
                amount: 4990,
                currencyCode: "RUB",
                billingCycle: .annual,
                nextChargeDate: cal.date(byAdding: .day, value: 12, to: now)!
            )
        ])
        .padding(.vertical, Spacing.lg)
    }
    .background(ColorTokens.background)
}

#Preview("Empty") {
    UpcomingChargesSectionView(items: [])
        .padding(.vertical, Spacing.lg)
        .background(ColorTokens.background)
}
