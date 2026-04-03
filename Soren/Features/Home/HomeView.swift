import SwiftUI

// MARK: - Home View

/// Dashboard — the app's command center.
/// Financial snapshot, upcoming charges, active trials, quick insights.
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @State private var viewModel: HomeViewModel?

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
            .background(ColorTokens.background)
            .toolbarVisibility(.hidden, for: .navigationBar)
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
            addSubscription()
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
