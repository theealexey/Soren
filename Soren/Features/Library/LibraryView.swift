import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Library View

/// Full subscription list with inline search, status filters, and sorting.
/// "+" lives in the global context bar (RootView). Sort is inline in the summary bar.
struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @Environment(\.navigateToItem) private var navigateToItem
    @State private var viewModel: LibraryViewModel?
    @State private var pendingDeleteItem: RecurringItem?
    @FocusState private var isSearchFocused: Bool

    /// Maximum width of the populated library content column.
    /// Keeps the search bar, filter chips, summary row, and item list
    /// visually cohesive on iPad and Mac rather than stretching to full screen width.
    /// On any iPhone (max 430 pt wide) this cap is never reached.
    private let libraryContentMaxWidth: CGFloat = 640
    private let floatingPillContentInset: CGFloat = Spacing.xxxl + Spacing.xl

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
            let vm = container.makeLibraryViewModel()
            self.viewModel = vm
            vm.load()
        }
        .onChange(of: container.itemsVersion) { _, _ in
            viewModel?.load()
        }
        .alert(
            "Удалить подписку?",
            isPresented: Binding(
                get: { pendingDeleteItem != nil },
                set: { if !$0 { pendingDeleteItem = nil } }
            )
        ) {
            Button("Удалить", role: .destructive) {
                if let item = pendingDeleteItem {
                    viewModel?.deleteItem(item)
                    container.itemsVersion += 1
                }
                pendingDeleteItem = nil
            }
            Button("Отмена", role: .cancel) { pendingDeleteItem = nil }
        } message: {
            if let item = pendingDeleteItem {
                Text("«\(item.title)» будет удалена без возможности восстановления.")
            }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private func libraryContent(_ vm: LibraryViewModel) -> some View {
        Group {
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
        .task(id: vm.aggregationRevision) {
            let revision = vm.aggregationRevision
            await vm.refreshCurrencyAggregation(revision: revision)
        }
    }

    // MARK: - Populated Library

    private func populatedLibrary(_ vm: LibraryViewModel) -> some View {
        List {
            if vm.filteredItems.isEmpty {
                noResults(vm)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: Spacing.xs, leading: 0, bottom: 0, trailing: 0))
            } else {
                ForEach(vm.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            Button {
                                dismissSearchFocus()
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
                            .listRowBackground(ColorTokens.surface)
                            .listRowInsets(EdgeInsets(
                                top: Spacing.xs,
                                leading: Spacing.lg,
                                bottom: Spacing.xs,
                                trailing: Spacing.lg
                            ))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeleteItem = item
                                } label: {
                                    Label("Удалить", systemImage: "trash.fill")
                                }
                            }
                        }
                    } header: {
                        if let title = section.title {
                            SectionHeader(title)
                                .textCase(nil)
                                .listRowInsets(EdgeInsets(
                                    top: Spacing.sm,
                                    leading: Spacing.lg,
                                    bottom: Spacing.xxxs,
                                    trailing: Spacing.lg
                                ))
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissSearchFocus()
            }
        )
        .onScrollPhaseChange { _, newPhase in
            if newPhase.isScrolling {
                dismissSearchFocus()
            }
        }
        .refreshable {
            vm.load()
        }
        // Entire header block lives outside the List: search + chips + summary share
        // one VStack so vertical rhythm is governed by a single layout system.
        // The List contains only subscription card sections (plus the empty-state row).
        .safeAreaInset(edge: .top, spacing: 0) {
            // VStack spacing controls chips→summary (kept at sm = 12pt, small-to-medium).
            // searchBar adds an extra .padding(.bottom, xxs) on top of the VStack gap
            // to get the larger search→chips separation (12 + 4 = 16pt) without splitting
            // the children into multiple containers.
            VStack(spacing: Spacing.sm) {
                searchBar(vm)
                    .padding(.bottom, Spacing.xs)
                filterChips(vm)
                if !vm.filteredItems.isEmpty {
                    summaryBar(vm)
                }
            }
            .padding(.top, Spacing.lg + Spacing.xxs)
            .background(ColorTokens.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: floatingPillContentInset)
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
            .focused($isSearchFocused)
            .submitLabel(.done)
            .onSubmit {
                dismissSearchFocus()
            }

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
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(ColorTokens.surfaceElevated, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(ColorTokens.separator.opacity(0.4), lineWidth: 0.5)
        }
        .padding(.horizontal, Spacing.lg)
    }

    // MARK: - Filter Chips

    private func filterChips(_ vm: LibraryViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xxs) {
                ForEach(LibraryViewModel.StatusFilter.allCases) { filter in
                    let count = vm.filterCounts[filter] ?? 0
                    let isSelected = vm.activeFilter == filter

                    Button {
                        dismissSearchFocus()
                        withAnimation(MotionTokens.snappy) { vm.activeFilter = filter }
                        HapticEngine.selection()
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            // Icon only shown when this chip is active — keeps unselected chips
                            // light text-only pills; the icon makes the selected state pop.
                            if let icon = filter.icon, isSelected {
                                Image(systemName: icon)
                                    .font(Typography.overline)
                            }

                            Text(filter.title)
                                .font(Typography.footnote)

                            if count > 0 && filter != .all {
                                Text(verbatim: "\(count)")
                                    .font(Typography.footnote)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isSelected ? .white.opacity(0.8) : ColorTokens.textTertiary)
                            }
                        }
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .foregroundStyle(isSelected ? .white : ColorTokens.textSecondary)
                        .background(
                            isSelected
                                ? AnyShapeStyle(ColorTokens.accent)
                                : AnyShapeStyle(Color.clear),
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
            Text(verbatim: String(localized: "\(vm.filteredItems.count) подписок"))
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            monthlyTotal(vm)

            sortMenu(vm)
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func monthlyTotal(_ vm: LibraryViewModel) -> some View {
        if let aggregation = vm.filteredMonthlyAggregation {
            VStack(alignment: .trailing, spacing: Spacing.xxxs) {
                if let total = aggregation.total, total.amount > .zero {
                    AmountLabel(
                        total.amount,
                        currency: total.currencyCode,
                        size: .small,
                        cycle: .monthly
                    )
                } else if aggregation.total == nil {
                    Text(String(localized: "Курсы валют недоступны"))
                        .font(Typography.footnote)
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                switch aggregation {
                case let .complete(_, metadata):
                    staleRateLabel(metadata)

                case let .partial(_, missingCodes, metadata):
                    Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                        .font(Typography.footnote)
                        .foregroundStyle(ColorTokens.warning)
                    staleRateLabel(metadata)

                case let .unavailable(_, missingCodes, _, metadata):
                    if !missingCodes.isEmpty {
                        Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                            .font(Typography.footnote)
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    staleRateLabel(metadata)
                }
            }
        }
    }

    @ViewBuilder
    private func staleRateLabel(_ metadata: SpendAggregationRateMetadata?) -> some View {
        if let metadata, case .stale = metadata.freshness {
            Text(String(localized: "По сохранённому курсу"))
                .font(Typography.footnote)
                .foregroundStyle(ColorTokens.warning)
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

    private func dismissSearchFocus() {
        isSearchFocused = false
#if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .endEditing(true)
#endif
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
