import SwiftUI

// MARK: - Components Preview

/// Visual showcase of all Design System components.
/// Run to verify consistency across cards, rows, badges, states.
struct ComponentsPreview: View {
    @State private var chipStates = [true, false, false, true]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                cardsSection
                statsSection
                listRowsSection
                insightsSection
                chipsSection
                iconsSection
                statesSection
            }
            .padding(Spacing.lg)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Cards

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Cards")

            PremiumCard { Text("Standard").font(Typography.body) }
            PremiumCard(.elevated) { Text("Elevated").font(Typography.body) }
            PremiumCard(.glass) { Text("Glass").font(Typography.body) }
            PremiumCard(.tinted(ColorTokens.warning)) { Text("Tinted").font(Typography.body) }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Stat Blocks")

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(title: "Monthly", amount: 4299, currency: "RUB", trend: .up(12.5))
                }

                PremiumCard(.elevated) {
                    StatBlock(title: "Yearly", amount: 51_588, currency: "RUB", trend: .down(3))
                }
            }
        }
    }

    // MARK: - List Rows

    private var listRowsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("List Rows", action: "See all") {}

            PremiumCard {
                VStack(spacing: 0) {
                    SorenListRow(
                        title: "YouTube Premium",
                        subtitle: "Next: Apr 12",
                        amount: 299,
                        currency: "RUB",
                        iconName: "play.rectangle.fill",
                        iconColor: ColorTokens.categoryVideo
                    )

                    Divider().padding(.leading, 52)

                    SorenListRow(
                        title: "Яндекс Плюс",
                        subtitle: "Trial ends in 3 days",
                        amount: 399,
                        currency: "RUB",
                        iconName: "star.fill",
                        iconColor: .purple,
                        badge: .trial
                    )

                    Divider().padding(.leading, 52)

                    SorenListRow(
                        title: "ChatGPT Plus",
                        subtitle: "Payment failed",
                        amount: 20,
                        currency: "USD",
                        iconName: "brain.head.profile",
                        iconColor: ColorTokens.categoryAI,
                        badge: .failed
                    )
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Insight Cards")

            InsightCard(
                icon: "exclamationmark.triangle",
                title: "4 charges in next 6 days",
                subtitle: "Total: ₽2,847",
                severity: .warning
            )

            InsightCard(
                icon: "arrow.down.right",
                title: "You saved ₽1,200 vs last month",
                severity: .positive
            )
        }
    }

    // MARK: - Chips

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Filter Chips")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    FilterChip("All", isSelected: $chipStates[0])
                    FilterChip("Active", icon: "checkmark.circle", tint: ColorTokens.success, isSelected: $chipStates[1])
                    FilterChip("Trial", icon: "clock", tint: ColorTokens.warning, isSelected: $chipStates[2])
                    FilterChip("Annual", icon: "calendar", isSelected: $chipStates[3])
                }
            }
        }
    }

    // MARK: - Icons

    private var iconsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Provider Icons")

            HStack(spacing: Spacing.md) {
                ProviderIcon(systemName: "play.rectangle.fill", color: .red, size: .small)
                ProviderIcon(systemName: "star.fill", color: .purple, size: .medium)
                ProviderIcon(systemName: "icloud.fill", color: ColorTokens.categoryCloud, size: .large)
            }
        }
    }

    // MARK: - States

    private var statesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Empty & Error States")

            PremiumCard {
                EmptyStateView(
                    icon: "tray",
                    title: "No subscriptions",
                    subtitle: "Add your first recurring payment.",
                    actionTitle: "Add Item"
                ) {}
            }

            PremiumCard {
                ErrorStateView(
                    message: "Could not load data."
                ) {}
            }
        }
    }
}

// MARK: - Preview

#Preview("Light") {
    ComponentsPreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ComponentsPreview()
        .preferredColorScheme(.dark)
}
