import SwiftUI

// MARK: - Upcoming Charges Section

/// Dashboard section listing the next few charges with navigation links.
struct UpcomingChargesSection: View {
    let items: [RecurringItem]
    let maxItems: Int
    let onTap: (RecurringItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Ближайшие списания"))

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(maxItems).enumerated()), id: \.element.id) { index, item in
                        Button { onTap(item) } label: {
                            SorenListRow(
                                title: item.title,
                                subtitle: RecurringItemFormatter.chargeSubtitle(for: item),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                                providerTemplate: item.providerTemplate,
                                category: item.category,
                                badge: RecurringItemFormatter.badge(for: item)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < min(items.count, maxItems) - 1 {
                            Divider()
                                .padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        UpcomingChargesSection(
            items: [
                RecurringItem(
                    title: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    nextChargeDate: Calendar.current.date(byAdding: .day, value: 2, to: .now)!
                ),
                RecurringItem(
                    title: "Spotify",
                    category: .music,
                    amount: 199,
                    nextChargeDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!
                ),
            ],
            maxItems: 5,
            onTap: { _ in }
        )
        .padding(Spacing.lg)
        .background(ColorTokens.background)
    }
}
