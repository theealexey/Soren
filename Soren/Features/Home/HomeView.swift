import SwiftUI

// MARK: - Home View

/// Dashboard — the app's command center.
/// Financial snapshot, upcoming charges, active trials, quick insights.
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: HomeViewModel?
    @State private var showAddSheet = false
    @State private var showSettings = false

    private let maxUpcomingItems = 5

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    dashboardContent(viewModel)
                } else {
                    LoadingStateView()
                }
            }
            .navigationTitle("Главная")
            .background(ColorTokens.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: {
                viewModel?.load(forceReload: true)
            }) {
                addSubscriptionSheet
            }
            .task {
                let vm = HomeViewModel(
                    repositories: container.repositories,
                    preferences: container.preferences
                )
                vm.load()
                self.viewModel = vm
            }
            .navigationDestination(for: RecurringItem.self) { item in
                ItemDetailsView(
                    viewModel: ItemDetailsViewModel(
                        item: item,
                        repositories: container.repositories
                    )
                )
            }
        }
    }

    private var addSubscriptionSheet: some View {
        NavigationStack {
            ProviderPickerView(
                viewModel: AddSubscriptionViewModel(container: container)
            )
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(_ vm: HomeViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(
                message: "Не удалось загрузить данные"
            ) {
                vm.load(forceReload: true)
            }
        } else if !vm.isLoaded {
            LoadingStateView()
        } else if vm.summary == .empty && vm.upcomingCharges.isEmpty {
            emptyDashboard
        } else {
            scrollableContent(vm)
        }
    }

    // MARK: - Scrollable Content

    private func scrollableContent(_ vm: HomeViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                financialSnapshot(vm)

                if !vm.upcomingCharges.isEmpty {
                    upcomingSection(vm.upcomingCharges)
                }

                if !vm.activeTrials.isEmpty {
                    trialsSection(vm.activeTrials)
                }

                quickInsights(vm)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            viewModel?.load(forceReload: true)
        }
    }

    // MARK: - Financial Snapshot

    private func financialSnapshot(_ vm: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Обзор")

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: vm.summary.monthlyTotal,
                        currency: vm.defaultCurrency,
                        amountSize: .large
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: vm.summary.yearlyProjection,
                        currency: vm.defaultCurrency,
                        amountSize: .large
                    )
                }
            }

            HStack(spacing: Spacing.sm) {
                metricChip(
                    icon: "repeat",
                    value: "\(vm.summary.activeItemCount)",
                    label: String(localized: "активных")
                )

                if vm.summary.activeTrialCount > 0 {
                    metricChip(
                        icon: "clock",
                        value: "\(vm.summary.activeTrialCount)",
                        label: HomeViewModel.pluralTrial(vm.summary.activeTrialCount)
                    )
                }
            }
        }
    }

    // MARK: - Upcoming Charges

    private func upcomingSection(_ items: [RecurringItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Ближайшие списания")

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(items.prefix(maxUpcomingItems).enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item) {
                            SorenListRow(
                                title: item.title,
                                subtitle: HomeViewModel.chargeSubtitle(for: item),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: HomeViewModel.cycleLabel(for: item.billingCycle),
                                iconName: item.category.systemIconName,
                                iconColor: item.category.color,
                                badge: HomeViewModel.badge(for: item)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < min(items.count, maxUpcomingItems) - 1 {
                            Divider()
                                .padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Active Trials

    private func trialsSection(_ trials: [RecurringItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Пробные периоды")

            ForEach(trials) { trial in
                InsightCard(
                    icon: "clock.badge.exclamationmark",
                    title: trial.title,
                    subtitle: HomeViewModel.trialSubtitle(for: trial),
                    severity: HomeViewModel.trialSeverity(for: trial)
                )
            }
        }
    }

    // MARK: - Quick Insights

    @ViewBuilder
    private func quickInsights(_ vm: HomeViewModel) -> some View {
        if !vm.insights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Аналитика")

                ForEach(vm.insights, id: \.title) { insight in
                    InsightCard(
                        icon: insight.icon,
                        title: insight.title,
                        subtitle: insight.subtitle,
                        severity: insight.severity
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyDashboard: some View {
        EmptyStateView(
            icon: "house",
            title: "Пока пусто",
            subtitle: "Добавьте первую подписку, чтобы увидеть дашборд с аналитикой расходов.",
            actionTitle: "Добавить"
        ) {
            showAddSheet = true
        }
    }

    // MARK: - Helpers

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
    HomeView()
        .environment(
            AppContainer(
                repositories: RepositoryContainer(
                    context: try! SorenModelContainer.inMemory().mainContext
                )
            )
        )
}
