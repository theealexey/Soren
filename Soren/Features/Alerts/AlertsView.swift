import SwiftUI

// MARK: - Alerts View

/// Alerts Center: groups items requiring attention by urgency.
/// Replaces Settings tab — settings will move to toolbar gear icon.
struct AlertsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: AlertsViewModel?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    alertsContent(viewModel)
                } else {
                    LoadingStateView()
                }
            }
            .navigationTitle("Алерты")
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
            .task {
                let vm = AlertsViewModel(repositories: container.repositories)
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

    // MARK: - Content

    @ViewBuilder
    private func alertsContent(_ vm: AlertsViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(
                message: "Не удалось загрузить алерты",
                retryAction: { vm.load() }
            )
        } else if vm.alerts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    summaryHeader(vm)

                    ForEach(vm.alertSections) { section in
                        alertSection(section)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            .refreshable { vm.load() }
        }
    }

    // MARK: - Summary Header

    private func summaryHeader(_ vm: AlertsViewModel) -> some View {
        VStack(spacing: Spacing.sm) {
            if vm.alerts.criticalCount > 0 {
                InsightCard(
                    icon: "exclamationmark.triangle.fill",
                    title: criticalTitle(vm.alerts),
                    subtitle: "Требуется внимание",
                    severity: .critical
                )
            }

            if vm.alerts.totalCount > vm.alerts.criticalCount {
                let nonCritical = vm.alerts.totalCount - vm.alerts.criticalCount
                InsightCard(
                    icon: "bell.fill",
                    title: alertCountTitle(nonCritical),
                    subtitle: "Списания и триалы",
                    severity: .warning
                )
            }
        }
    }

    // MARK: - Alert Section

    private func alertSection(_ section: AlertSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(section.title)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item) {
                            SorenListRow(
                                title: item.title,
                                subtitle: subtitle(for: item, in: section),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: HomeViewModel.cycleLabel(for: item.billingCycle),
                                iconName: item.category.systemIconName,
                                iconColor: item.category.color,
                                badge: HomeViewModel.badge(for: item)
                            )
                        }
                        .buttonStyle(.plain)

                        if index < section.items.count - 1 {
                            Divider()
                                .padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: "Нет активных алертов",
            subtitle: "Все подписки в порядке. Мы уведомим вас, когда что-то потребует внимания."
        )
    }

    // MARK: - Helpers

    private func subtitle(for item: RecurringItem, in section: AlertSection) -> String {
        if section.title == "Пробный период заканчивается" {
            return HomeViewModel.trialSubtitle(for: item)
        }
        return HomeViewModel.chargeSubtitle(for: item)
    }

    private func criticalTitle(_ alerts: AlertsResult) -> String {
        let count = alerts.criticalCount
        if count == 1 { return "1 критическая проблема" }
        return "\(count) критических проблем"
    }

    private func alertCountTitle(_ count: Int) -> String {
        if count == 1 { return "1 предупреждение" }
        return "\(count) предупреждений"
    }
}

// MARK: - Preview

#Preview {
    AlertsView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
