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
            SectionHeader("Карточки")

            PremiumCard { Text("Стандартная").font(Typography.body) }
            PremiumCard(.elevated) { Text("Приподнятая").font(Typography.body) }
            PremiumCard(.glass) { Text("Стеклянная").font(Typography.body) }
            PremiumCard(.tinted(ColorTokens.warning)) { Text("Предупреждение").font(Typography.body) }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Статистика")

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(title: "В месяц", amount: 4299, currency: "RUB", trend: .up(12.5))
                }

                PremiumCard(.elevated) {
                    StatBlock(title: "В год", amount: 51_588, currency: "RUB", trend: .down(3))
                }
            }
        }
    }

    // MARK: - List Rows

    private var listRowsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Список", action: "Все") {}

            PremiumCard {
                VStack(spacing: 0) {
                    SorenListRow(
                        title: "YouTube Premium",
                        subtitle: "Списание: 12 апр",
                        amount: 299,
                        currency: "RUB",
                        providerTemplate: ProviderCatalog.template(forProviderID: "youtube_premium"),
                        category: .video
                    )

                    Divider().padding(.leading, SorenListRow.dividerInset)

                    SorenListRow(
                        title: "Яндекс Плюс",
                        subtitle: "Триал через 3 дня",
                        amount: 399,
                        currency: "RUB",
                        providerTemplate: ProviderCatalog.template(forProviderID: "yandex_plus"),
                        category: .shopping,
                        badge: .trial
                    )

                    Divider().padding(.leading, SorenListRow.dividerInset)

                    SorenListRow(
                        title: "ChatGPT Plus",
                        subtitle: "Ошибка оплаты",
                        amount: 20,
                        currency: "USD",
                        providerTemplate: ProviderCatalog.template(forProviderID: "chatgpt_plus"),
                        category: .aiTools,
                        badge: .failed
                    )
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Инсайты")

            InsightCard(
                icon: "exclamationmark.triangle",
                title: "4 списания за 6 дней",
                subtitle: "Итого: ₽2 847",
                severity: .warning
            )

            InsightCard(
                icon: "arrow.down.right",
                title: "Сэкономлено ₽1 200 за месяц",
                severity: .positive
            )
        }
    }

    // MARK: - Chips

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Фильтры")

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
            SectionHeader("Иконки провайдеров")

            HStack(spacing: Spacing.md) {
                ProviderIcon(provider: ProviderCatalog.global.first { $0.id == "netflix" }!, size: .small)
                ProviderIcon(provider: ProviderCatalog.global.first { $0.id == "spotify" }!, size: .medium)
                ProviderIcon(provider: ProviderCatalog.global.first { $0.id == "icloud" }!, size: .large)
            }
        }
    }

    // MARK: - States

    private var statesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Пустые и ошибочные состояния")

            PremiumCard {
                EmptyStateView(
                    icon: "tray",
                    title: "Нет подписок",
                    subtitle: "Добавьте первый рекуррентный платёж.",
                    actionTitle: "Добавить"
                ) {}
            }

            PremiumCard {
                ErrorStateView(
                    message: "Не удалось загрузить данные."
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
