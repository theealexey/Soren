import SwiftUI

// MARK: - Library View

/// Full subscription list with native search, status filters, and sorting.
/// "+" lives in the global context bar (RootView). Sort lives in the nav toolbar.
struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @State private var viewModel: LibraryViewModel?
    @State private var selectedItem: RecurringItem?

    /// Binding bridged to the optional ViewModel — safe to pass to .searchable.
    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel?.searchText ?? "" },
            set: { viewModel?.searchText = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    libraryContent(viewModel)
                } else {
                    LoadingStateView()
                }
            }
            .background(ColorTokens.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: searchBinding,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Поиск подписок"
            )
            .toolbar {
                if let vm = viewModel {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        sortMenu(vm)
                    }
                }
            }
            .task {
                guard viewModel == nil else { return }
                let vm = LibraryViewModel(repositories: container.repositories, preferences: container.preferences)
                self.viewModel = vm   // assign first — eliminates nil loading flash
                vm.load()
            }
            .onChange(of: container.itemsVersion) { _, _ in
                viewModel?.load()
            }
            .navigationDestination(item: $selectedItem) { item in
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
    private func libraryContent(_ vm: LibraryViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(message: "Не удалось загрузить подписки") {
                vm.load()
            }
        } else if !vm.isLoaded {
            LoadingStateView()
        } else if vm.allItems.isEmpty {
            emptyLibrary
        } else {
            populatedLibrary(vm)
        }
    }

    // MARK: - Populated Library

    private func populatedLibrary(_ vm: LibraryViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                filterChips(vm)

                summaryBar(vm)

                if vm.filteredItems.isEmpty {
                    noResults(vm)
                } else {
                    itemsList(vm)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            vm.load()
        }
    }

    // MARK: - Filter Chips

    private func filterChips(_ vm: LibraryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(LibraryViewModel.StatusFilter.allCases) { filter in
                    let count = vm.filterCounts[filter] ?? 0
                    let isSelected = vm.activeFilter == filter

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
                                Text(verbatim: "\(count)")
                                    .font(Typography.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .foregroundStyle(isSelected ? .white : ColorTokens.textSecondary)
                        .background(
                            isSelected
                                ? AnyShapeStyle(ColorTokens.accent)
                                : AnyShapeStyle(ColorTokens.surfaceElevated),
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? .clear : ColorTokens.separator.opacity(0.5),
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - Summary Bar

    private func summaryBar(_ vm: LibraryViewModel) -> some View {
        HStack {
            Text(verbatim: "\(vm.filteredItems.count)")
                .font(Typography.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)
            + Text(" ")
            + Text(pluralSubscription(vm.filteredItems.count))
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            if vm.filteredMonthlyTotal > 0 {
                AmountLabel(
                    vm.filteredMonthlyTotal,
                    currency: vm.defaultCurrency,
                    size: .small,
                    cycle: .monthly
                )
            }
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Items List

    private func itemsList(_ vm: LibraryViewModel) -> some View {
        PremiumCard {
            VStack(spacing: 0) {
                ForEach(Array(vm.filteredItems.enumerated()), id: \.element.id) { index, item in
                    Button { selectedItem = item } label: {
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
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Sort Menu

    private func sortMenu(_ vm: LibraryViewModel) -> some View {
        Menu {
            ForEach(LibraryViewModel.SortOrder.allCases) { order in
                Button {
                    withAnimation(MotionTokens.smooth) { vm.sortOrder = order }
                } label: {
                    Label(order.title, systemImage: order.icon)
                }
                .disabled(vm.sortOrder == order)
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(Typography.bodyMedium)
                .foregroundStyle(ColorTokens.accent)
        }
    }

    // MARK: - No Results

    private func noResults(_ vm: LibraryViewModel) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(Typography.emptyStateAmount)
                .foregroundStyle(ColorTokens.textTertiary)

            if !vm.searchText.isEmpty {
                Text("Ничего не найдено по запросу «\(vm.searchText)»")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Нет подписок в категории «\(vm.activeFilter.title)»")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty Library

    private var emptyLibrary: some View {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: "Нет подписок",
            subtitle: "Добавьте подписки и сервисы, чтобы отслеживать расходы и не пропускать списания.",
            actionTitle: "Добавить"
        ) {
            addSubscription()
        }
    }

    // MARK: - Helpers

    private func pluralSubscription(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return String(localized: "подписка") }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return String(localized: "подписки") }
        return String(localized: "подписок")
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .environment(
            AppContainer(
                repositories: RepositoryContainer(
                    context: try! SorenModelContainer.inMemory().mainContext
                )
            )
        )
}
