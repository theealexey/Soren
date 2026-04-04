import SwiftUI

// MARK: - Home View

/// Dashboard: financial snapshot at the top, then status-filtered
/// subscription list (Все / Активные / Пробные / Пауза).
struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
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
            .onChange(of: container.itemsVersion) { _, _ in
                viewModel?.loadLocalData(forceReload: true)
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

    // MARK: - Content Router

    @ViewBuilder
    private func dashboardContent(_ vm: HomeViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(message: "Не удалось загрузить данные") {
                Task { await vm.load(forceReload: true) }
            }
        } else if !vm.isLoaded {
            LoadingStateView()
        } else if vm.allItems.isEmpty {
            emptyDashboard
        } else {
            scrollableContent(vm)
        }
    }

    // MARK: - Scrollable Content

    private func scrollableContent(_ vm: HomeViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                // Financial overview
                FinancialSnapshotSection(
                    summary: vm.summary,
                    defaultCurrency: vm.defaultCurrency,
                    ratesLastUpdated: vm.ratesLastUpdated,
                    isRatesStale: vm.isRatesStale
                )

                // Status filter chips + list
                subscriptionSection(vm)

                // Actionable insights (overdue, upcoming etc.)
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

    // MARK: - Subscription Section

    @ViewBuilder
    private func subscriptionSection(_ vm: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Подписки"))

            // Filter chips
            filterChips(vm)

            // List or contextual empty
            if vm.filteredItems.isEmpty {
                emptyFilter(vm.activeFilter)
            } else {
                itemsList(vm)
            }
        }
    }

    // MARK: - Filter Chips

    private func filterChips(_ vm: HomeViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(HomeViewModel.HomeFilter.allCases) { filter in
                    let count = vm.filterCounts[filter] ?? 0
                    let isActive = vm.activeFilter == filter

                    Button {
                        withAnimation(MotionTokens.snappy) { vm.activeFilter = filter }
                        HapticEngine.selection()
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            if let icon = filter.icon {
                                Image(systemName: icon)
                                    .font(Typography.overline)
                            }

                            Text(filter.title)
                                .font(Typography.captionMedium)

                            if count > 0 && filter != .all {
                                Text("\(count)")
                                    .font(Typography.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isActive ? .white.opacity(0.8) : ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .foregroundStyle(isActive ? .white : ColorTokens.textSecondary)
                        .background(
                            isActive
                                ? AnyShapeStyle(ColorTokens.accent)
                                : AnyShapeStyle(ColorTokens.surfaceElevated),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isActive ? .clear : ColorTokens.separator.opacity(0.5),
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                }
            }
        }
    }

    // MARK: - Items List

    private func itemsList(_ vm: HomeViewModel) -> some View {
        PremiumCard {
            VStack(spacing: 0) {
                ForEach(Array(vm.filteredItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item) {
                        SorenListRow(
                            title: item.title,
                            subtitle: RecurringItemFormatter.subtitle(for: item),
                            amount: item.amount,
                            currency: item.currencyCode,
                            cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                            providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                            category: item.category,
                            badge: RecurringItemFormatter.badge(for: item)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < vm.filteredItems.count - 1 {
                        Divider()
                            .padding(.leading, SorenListRow.dividerInset)
                    }
                }
            }
        }
    }

    // MARK: - Empty Filter State

    @ViewBuilder
    private func emptyFilter(_ filter: HomeViewModel.HomeFilter) -> some View {
        let message: String = switch filter {
        case .all:    String(localized: "Нет активных подписок")
        case .active: String(localized: "Нет активных подписок")
        case .trial:  String(localized: "Нет пробных периодов")
        case .paused: String(localized: "Нет приостановленных подписок")
        }

        HStack {
            Spacer()
            Text(message)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textTertiary)
                .padding(.vertical, Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Empty Dashboard

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
