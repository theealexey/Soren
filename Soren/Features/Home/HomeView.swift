import SwiftUI

// MARK: - Home View

/// Dashboard — the app's command center.
/// Financial snapshot, upcoming charges, active trials, quick insights.
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: HomeViewModel?
    @State private var activeSheet: Sheet?

    private enum Sheet: Identifiable {
        case settings
        case addSubscription

        var id: Self { self }
    }

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
                        activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .accessibilityLabel(Text("Настройки"))
                    .accessibilityHint(Text("Открыть настройки приложения"))
                }
            }
            .sheet(item: $activeSheet, onDismiss: {
                Task { await viewModel?.load(forceReload: true) }
            }) { sheet in
                switch sheet {
                case .settings:
                    NavigationStack {
                        SettingsView()
                    }
                case .addSubscription:
                    addSubscriptionSheet
                }
            }
            .task {
                let vm = HomeViewModel(
                    repositories: container.repositories,
                    preferences: container.preferences,
                    exchangeRateProvider: container.exchangeRateProvider
                )
                await vm.load()
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
                Task { await vm.load(forceReload: true) }
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
                FinancialSnapshotSection(
                    summary: vm.summary,
                    defaultCurrency: vm.defaultCurrency,
                    ratesLastUpdated: vm.ratesLastUpdated,
                    isRatesStale: vm.isRatesStale
                )

                if !vm.upcomingCharges.isEmpty {
                    UpcomingChargesSection(
                        items: vm.upcomingCharges,
                        maxItems: maxUpcomingItems
                    )
                }

                if !vm.activeTrials.isEmpty {
                    ActiveTrialsSection(trials: vm.activeTrials)
                }

                if !vm.insights.isEmpty {
                    QuickInsightsSection(insights: vm.insights)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            await viewModel?.load(forceReload: true)
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
            activeSheet = .addSubscription
        }
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
