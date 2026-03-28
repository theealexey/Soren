import SwiftUI

// MARK: - Home View

/// Dashboard — the app's command center.
/// Financial snapshot, upcoming charges, active trials, quick insights.
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: HomeViewModel?

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
            .task {
                let vm = HomeViewModel(repositories: container.repositories)
                vm.load()
                self.viewModel = vm
            }
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private func dashboardContent(_ vm: HomeViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(
                message: "Не удалось загрузить данные"
            ) {
                vm.load()
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
                financialSnapshot(vm.summary)

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
            viewModel?.load()
        }
    }

    // MARK: - Financial Snapshot

    private func financialSnapshot(_ summary: DashboardSummary) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader("Обзор")

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: summary.monthlyTotal,
                        currency: "RUB",
                        amountSize: .large
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: summary.yearlyProjection,
                        currency: "RUB",
                        amountSize: .large
                    )
                }
            }

            HStack(spacing: Spacing.sm) {
                metricChip(
                    icon: "repeat",
                    value: "\(summary.activeItemCount)",
                    label: "активных"
                )

                if summary.activeTrialCount > 0 {
                    metricChip(
                        icon: "clock",
                        value: "\(summary.activeTrialCount)",
                        label: pluralTrial(summary.activeTrialCount)
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
                    ForEach(Array(items.prefix(5).enumerated()), id: \.element.id) { index, item in
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

                        if index < min(items.count, 5) - 1 {
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
                    severity: trialSeverity(for: trial)
                )
            }
        }
    }

    // MARK: - Quick Insights

    @ViewBuilder
    private func quickInsights(_ vm: HomeViewModel) -> some View {
        let insights = buildInsights(vm)
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader("Аналитика")

                ForEach(insights, id: \.title) { insight in
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
            // Navigation to Add Item — wired in future session
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

    private func trialSeverity(for item: RecurringItem) -> InsightCard.Severity {
        guard let days = item.daysUntilTrialEnd else { return .info }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .info
    }

    /// Russian pluralization for "пробный период" count.
    private func pluralTrial(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return "пробный" }
        return "пробных"
    }
}

// MARK: - Insight Builder

private extension HomeView {

    struct InsightData {
        let icon: String
        let title: String
        let subtitle: String?
        let severity: InsightCard.Severity
    }

    func buildInsights(_ vm: HomeViewModel) -> [InsightData] {
        var result: [InsightData] = []

        let overdueCount = vm.upcomingCharges.filter { $0.daysUntilNextCharge < 0 }.count
        if overdueCount > 0 {
            result.append(InsightData(
                icon: "exclamationmark.triangle.fill",
                title: "\(overdueCount) просроченных списаний",
                subtitle: "Проверьте способы оплаты",
                severity: .critical
            ))
        }

        let weekTotal = vm.upcomingCharges.reduce(Decimal.zero) { $0 + $1.amount }
        if weekTotal > 0 && vm.upcomingCharges.count >= 2 {
            result.append(InsightData(
                icon: "calendar.badge.clock",
                title: "\(vm.upcomingCharges.count) списаний на этой неделе",
                subtitle: nil,
                severity: .info
            ))
        }

        let failedCount = vm.upcomingCharges.filter { $0.status == .failed }.count
        if failedCount > 0 {
            result.append(InsightData(
                icon: "creditcard.trianglebadge.exclamationmark",
                title: "\(failedCount) неудачных платежей",
                subtitle: "Требуется внимание",
                severity: .critical
            ))
        }

        return result
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
