import SwiftUI

// MARK: - Library View

/// Production Subscriptions collection backed by LibraryViewModel.
struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @Environment(\.navigateToItem) private var navigateToItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: LibraryViewModel?
    @State private var pendingDeleteItem: RecurringItem?

    var body: some View {
        Group {
            if let viewModel {
                libraryContent(viewModel)
            } else {
                LoadingStateView()
            }
        }
        .background(SoftClubColor.canvas.ignoresSafeArea())
        .navigationTitle(String(localized: "Подписки"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addSubscription()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "Добавить подписку"))
            }
        }
        .tint(SoftClubColor.textPrimary)
        .task {
            guard viewModel == nil else { return }
            let vm = container.makeLibraryViewModel()
            viewModel = vm
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
                if let item = pendingDeleteItem, let viewModel {
                    Task {
                        if await viewModel.deleteItem(item) {
                            container.itemsVersion += 1
                        }
                    }
                }
                pendingDeleteItem = nil
            }
            Button("Отмена", role: .cancel) {
                pendingDeleteItem = nil
            }
        } message: {
            if let item = pendingDeleteItem {
                Text("«\(item.title)» будет удалена без возможности восстановления.")
            }
        }
        .alert(
            "Ошибка",
            isPresented: deleteErrorBinding
        ) {
            if let viewModel, let item = failedDeleteItem(in: viewModel) {
                Button("Повторить") {
                    retryDelete(item, using: viewModel)
                }
            }
            Button("ОК", role: .cancel) {
                viewModel?.dismissError()
            }
        } message: {
            Text("Не удалось удалить подписку")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func libraryContent(_ vm: LibraryViewModel) -> some View {
        Group {
            if vm.failedAction == .load {
                ErrorStateView(message: "Не удалось загрузить подписки") {
                    vm.load()
                }
            } else if !vm.isLoaded {
                LoadingStateView()
            } else {
                loadedLibrary(vm)
            }
        }
        .task(id: vm.aggregationRevision) {
            let revision = vm.aggregationRevision
            await vm.refreshCurrencyAggregation(revision: revision)
        }
    }

    private func loadedLibrary(_ vm: LibraryViewModel) -> some View {
        @Bindable var vm = vm

        return Group {
            if vm.allItems.isEmpty {
                emptyLibrary
            } else {
                populatedLibrary(vm)
            }
        }
        .searchable(
            text: $vm.searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: Text("Поиск подписок")
        )
    }

    private func populatedLibrary(_ vm: LibraryViewModel) -> some View {
        List {
            collectionHeader(vm)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(
                    top: 0,
                    leading: 20,
                    bottom: 0,
                    trailing: 20
                ))

            if vm.filteredItems.isEmpty {
                noResults(vm)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: 20,
                        bottom: 0,
                        trailing: 20
                    ))
            } else {
                subscriptionSections(vm)
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(SoftClubColor.canvas)
        .refreshable {
            vm.load()
        }
    }

    private func collectionHeader(_ vm: LibraryViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            collectionControls(vm)
            summary(vm)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            SoftClubColor.subtleSeparator
                .opacity(0.55)
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func subscriptionSections(_ vm: LibraryViewModel) -> some View {
        ForEach(vm.sections) { section in
            if let title = section.title {
                sectionLabel(title)
            }

            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                subscriptionButton(
                    item,
                    showsSeparator: index < section.items.count - 1
                )
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(verbatim: title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SoftClubColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: 8,
                leading: 20,
                bottom: 4,
                trailing: 20
            ))
    }

    private func subscriptionButton(
        _ item: RecurringItem,
        showsSeparator: Bool
    ) -> some View {
        Button {
            navigateToItem(item)
        } label: {
            LibrarySubscriptionRow(item: item)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(
            top: 0,
            leading: 20,
            bottom: 0,
            trailing: 20
        ))
        .overlay(alignment: .bottom) {
            if showsSeparator {
                SoftClubColor.subtleSeparator
                    .opacity(0.55)
                    .frame(height: 0.5)
                    .padding(.leading, SorenListRow.dividerInset)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteItem = item
            } label: {
                Label("Удалить", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Collection Controls

    @ViewBuilder
    private func collectionControls(_ vm: LibraryViewModel) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                collectionControlLayout(vm)
            }
        } else {
            collectionControlLayout(vm)
        }
    }

    @ViewBuilder
    private func collectionControlLayout(_ vm: LibraryViewModel) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                filterMenu(vm)
                sortMenu(vm)
            }
        } else {
            HStack(spacing: 8) {
                filterMenu(vm)
                sortMenu(vm)
                Spacer(minLength: 0)
            }
        }
    }

    private func filterMenu(_ vm: LibraryViewModel) -> some View {
        Menu {
            ForEach(LibraryViewModel.StatusFilter.allCases) { filter in
                Button {
                    withAnimation(MotionTokens.snappy) {
                        vm.activeFilter = filter
                    }
                    HapticEngine.selection()
                } label: {
                    HStack {
                        Text(filter.title)
                        if filter == vm.activeFilter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityAddTraits(filter == vm.activeFilter ? .isSelected : [])
            }
        } label: {
            Label {
                Text(verbatim: vm.activeFilter.title)
            } icon: {
                Image(systemName: "line.3.horizontal.decrease")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SoftClubColor.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .softClubInteractiveGlass(in: Capsule())
        .accessibilityLabel(String(localized: "Фильтр"))
        .accessibilityValue(vm.activeFilter.title)
    }

    private func sortMenu(_ vm: LibraryViewModel) -> some View {
        Menu {
            ForEach(LibraryViewModel.SortOrder.allCases) { order in
                Button {
                    withAnimation(MotionTokens.smooth) {
                        vm.sortOrder = order
                    }
                    HapticEngine.selection()
                } label: {
                    HStack {
                        Text(order.title)
                        if order == vm.sortOrder {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityAddTraits(order == vm.sortOrder ? .isSelected : [])
            }
        } label: {
            Label {
                Text(verbatim: vm.sortOrder.shortTitle)
            } icon: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SoftClubColor.textSecondary)
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .softClubInteractiveGlass(in: Capsule())
        .accessibilityLabel(String(localized: "Сортировка"))
        .accessibilityValue(vm.sortOrder.title)
    }

    // MARK: - Summary

    private func summary(_ vm: LibraryViewModel) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    summaryCount(vm)
                    summaryAmount(vm, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    summaryCount(vm)
                    Spacer(minLength: 12)
                    summaryAmount(vm, alignment: .trailing)
                }
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(SoftClubColor.textSecondary)
        .accessibilityElement(children: .combine)
    }

    private func summaryCount(_ vm: LibraryViewModel) -> some View {
        Text(verbatim: String(localized: "\(vm.filteredItems.count) подписок"))
    }

    @ViewBuilder
    private func summaryAmount(
        _ vm: LibraryViewModel,
        alignment: HorizontalAlignment
    ) -> some View {
        if let aggregation = vm.filteredMonthlyAggregation {
            VStack(alignment: alignment, spacing: 3) {
                if let total = aggregation.total, total.amount > .zero {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(verbatim: OverviewMoneyFormatter.string(
                            amount: total.amount,
                            currencyCode: total.currencyCode
                        ))
                        .monospacedDigit()

                        Text(verbatim: "/")
                        Text(String(localized: "мес"))
                    }
                }

                switch aggregation {
                case let .complete(_, metadata):
                    staleRateLabel(metadata)

                case let .partial(_, missingCodes, metadata):
                    Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                        .foregroundStyle(SoftClubColor.warning)
                    staleRateLabel(metadata)

                case let .unavailable(_, missingCodes, _, metadata):
                    if missingCodes.isEmpty {
                        Text(String(localized: "Курсы валют недоступны"))
                    } else {
                        Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
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
                .foregroundStyle(SoftClubColor.warning)
        }
    }

    // MARK: - States

    private func noResults(_ vm: LibraryViewModel) -> some View {
        Group {
            if !vm.searchText.isEmpty {
                Text("Ничего не найдено по запросу «\(vm.searchText)»")
            } else {
                Text("Нет подписок в категории «\(vm.activeFilter.title)»")
            }
        }
        .font(.body)
        .foregroundStyle(SoftClubColor.textSecondary)
        .frame(maxWidth: .infinity, minHeight: 120)
        .multilineTextAlignment(.center)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 12) {
            Text("Нет подписок")
                .font(.headline)
                .foregroundStyle(SoftClubColor.textPrimary)

            Text("Добавьте подписки и сервисы, чтобы отслеживать расходы и не пропускать списания.")
                .font(.body)
                .foregroundStyle(SoftClubColor.textSecondary)
                .multilineTextAlignment(.center)

            Button("Добавить") {
                addSubscription()
            }
            .buttonStyle(.bordered)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Delete Error

    private var deleteErrorBinding: Binding<Bool> {
        Binding(
            get: {
                guard let failedAction = viewModel?.failedAction else { return false }
                if case .delete = failedAction { return true }
                return false
            },
            set: { isPresented in
                if !isPresented {
                    viewModel?.dismissError()
                }
            }
        )
    }

    private func failedDeleteItem(in vm: LibraryViewModel) -> RecurringItem? {
        guard case let .delete(itemID) = vm.failedAction else { return nil }
        return vm.allItems.first { $0.id == itemID }
    }

    private func retryDelete(_ item: RecurringItem, using vm: LibraryViewModel) {
        vm.dismissError()
        Task {
            if await vm.deleteItem(item) {
                container.itemsVersion += 1
            }
        }
    }
}

// MARK: - Subscription Row

private struct LibrarySubscriptionRow: View {
    let item: RecurringItem

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .foregroundStyle(SoftClubColor.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(String(localized: "Открыть управление подпиской"))
    }

    private var compactLayout: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                providerArtwork
                compactIdentity
                Spacer(minLength: 12)
                amount
            }

            HStack(alignment: .top, spacing: 12) {
                providerArtwork

                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        secondaryIdentity
                        Spacer(minLength: 8)
                        amount
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                providerArtwork
                Text(verbatim: item.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }

            secondaryIdentity
            amount
        }
    }

    @ViewBuilder
    private var providerArtwork: some View {
        if let provider = item.providerTemplate {
            ProviderIcon(provider: provider, size: .medium)
        } else {
            ProviderIcon(category: item.category, size: .medium)
        }
    }

    private var compactIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: item.title)
                .font(.body.weight(.medium))
                .fixedSize(horizontal: true, vertical: false)

            secondaryIdentity
        }
    }

    private var secondaryIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(
                item.effectiveNextChargeDate(),
                format: .dateTime.day().month(.wide)
            )
            .font(.footnote)
            .foregroundStyle(SoftClubColor.textSecondary)

            if let statusMetadata {
                Label {
                    Text(statusMetadata.title)
                } icon: {
                    Image(systemName: statusMetadata.systemImage)
                }
                .font(.caption)
                .foregroundStyle(SoftClubColor.textSecondary.opacity(0.9))
            }
        }
    }

    private var amount: some View {
        VStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
            spacing: 3
        ) {
            Text(verbatim: OverviewMoneyFormatter.string(
                amount: item.amount,
                currencyCode: item.currencyCode
            ))
            .font(.body)
            .monospacedDigit()

            Text(RecurringItemFormatter.cycleLabel(for: item.billingCycle).label)
                .font(.footnote)
                .foregroundStyle(SoftClubColor.textSecondary.opacity(0.82))
                .accessibilityLabel(
                    RecurringItemFormatter.cycleLabel(for: item.billingCycle).accessibilityText
                )
        }
    }

    private var statusMetadata: (title: String, systemImage: String)? {
        switch item.status {
        case .trial:
            (String(localized: "Пробный период"), "hourglass")
        case .paused:
            (String(localized: "На паузе"), "pause.circle")
        case .cancelled:
            (String(localized: "Отменена"), "xmark.circle")
        case .archived:
            (String(localized: "В архиве"), "archivebox")
        case .overdue:
            (item.status.displayName, "exclamationmark.circle")
        case .failed:
            (item.status.displayName, "creditcard.trianglebadge.exclamationmark")
        case .active, .dueSoon, .dueToday:
            nil
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LibraryView()
            .environment(
                AppContainer(
                    repositories: RepositoryContainer(
                        context: try! SorenModelContainer.inMemory().mainContext
                    )
                )
            )
    }
}
