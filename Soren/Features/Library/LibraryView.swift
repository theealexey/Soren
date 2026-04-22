import SwiftUI

// MARK: - Library View

/// Full subscription list with inline search, status filters, and sorting.
/// "+" lives in the global context bar (RootView). Sort is inline in the summary bar.
struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @Environment(\.navigateToItem) private var navigateToItem
    @State private var viewModel: LibraryViewModel?

    /// Maximum width of the populated library content column.
    /// Keeps the search bar, filter chips, summary row, and item list
    /// visually cohesive on iPad and Mac rather than stretching to full screen width.
    /// On any iPhone (max 430 pt wide) this cap is never reached.
    private let libraryContentMaxWidth: CGFloat = 640

    var body: some View {
        Group {
            if let viewModel {
                libraryContent(viewModel)
            } else {
                LoadingStateView()
            }
        }
        .background(ColorTokens.background)
        .task {
            guard viewModel == nil else { return }
            let vm = LibraryViewModel(repositories: container.repositories, preferences: container.preferences)
            self.viewModel = vm
            vm.load()
        }
        .onChange(of: container.itemsVersion) { _, _ in
            viewModel?.load()
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
                searchBar(vm)

                filterChips(vm)

                summaryBar(vm)

                if vm.filteredItems.isEmpty {
                    noResults(vm)
                } else {
                    itemsList(vm)
                }
            }
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: libraryContentMaxWidth)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .refreshable {
            vm.load()
        }
    }

    // MARK: - Search Bar

    private func searchBar(_ vm: LibraryViewModel) -> some View {
        @Bindable var vm = vm
        return HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textTertiary)

            TextField(
                String(localized: "Поиск подписок"),
                text: $vm.searchText
            )
            .textFieldStyle(.plain)
            .font(Typography.body)
            .foregroundStyle(ColorTokens.textPrimary)
            .autocorrectionDisabled()

            if !vm.searchText.isEmpty {
                Button {
                    vm.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceElevated, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.lg)
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

            sortMenu(vm)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Items List

    private func itemsList(_ vm: LibraryViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(vm.sections) { section in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if let title = section.title {
                        SectionHeader(title)
                            .padding(.horizontal, Spacing.lg)
                    }

                    PremiumCard {
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    navigateToItem(item)
                                } label: {
                                    SorenListRow(
                                        title: item.title,
                                        subtitle: RecurringItemFormatter.subtitle(for: item),
                                        amount: item.amount,
                                        currency: item.currencyCode,
                                        cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                                        providerTemplate: item.providerTemplate,
                                        category: item.category,
                                        badge: RecurringItemFormatter.badge(for: item)
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
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
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
                .frame(width: 36, height: 36)
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
