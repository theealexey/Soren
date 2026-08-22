#if DEBUG
import SwiftUI

enum SubscriptionsIAPrototypeVariant: String, Sendable {
    case nativeCollection
    case compactEditorial
    case searchFirst

    static func requested(in arguments: [String]) -> Self? {
        if arguments.contains("--subscriptions-anatomy-lock") { return .compactEditorial }
        if arguments.contains("--subscriptions-ia-a") { return .nativeCollection }
        if arguments.contains("--subscriptions-ia-b") { return .compactEditorial }
        if arguments.contains("--subscriptions-ia-c") { return .searchFirst }
        return nil
    }

    static func colorScheme(in arguments: [String]) -> ColorScheme {
        arguments.contains("--subscriptions-anatomy-dark") ? .dark : .light
    }

    static func dynamicTypeSize(in arguments: [String]) -> DynamicTypeSize {
        if arguments.contains("--subscriptions-anatomy-ax5") { return .accessibility5 }
        if arguments.contains("--subscriptions-anatomy-ax3") { return .accessibility3 }
        if arguments.contains("--subscriptions-anatomy-ax1") { return .accessibility1 }
        return .large
    }
}

struct SubscriptionsIAPrototypeHost: View {
    let variant: SubscriptionsIAPrototypeVariant
    let colorScheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize

    @State private var selectedTab: PrototypeTab = .subscriptions

    init(
        variant: SubscriptionsIAPrototypeVariant,
        colorScheme: ColorScheme = .light,
        dynamicTypeSize: DynamicTypeSize = .large
    ) {
        self.variant = variant
        self.colorScheme = colorScheme
        self.dynamicTypeSize = dynamicTypeSize
    }

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                tabNavigation
                    .tabBarMinimizeBehavior(.never)
                    .toolbarVisibility(.visible, for: .tabBar)
                    .toolbarBackground(.hidden, for: .tabBar)
            } else {
                tabNavigation
            }
        }
        .preferredColorScheme(colorScheme)
        .dynamicTypeSize(dynamicTypeSize)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .tint(SoftClubColor.textPrimary)
        .background(SoftClubColor.canvas.ignoresSafeArea())
    }

    private var tabNavigation: some View {
        TabView(selection: $selectedTab) {
            placeholder(title: "Обзор", systemImage: "house")
                .tag(PrototypeTab.overview)
                .tabItem {
                    Label {
                        Text(verbatim: "Обзор")
                    } icon: {
                        Image(systemName: "house")
                    }
                }

            NavigationStack {
                SubscriptionsIAPrototypeView(variant: variant)
            }
            .tag(PrototypeTab.subscriptions)
            .tabItem {
                Label {
                    Text(verbatim: "Подписки")
                } icon: {
                    Image(systemName: "list.bullet")
                }
            }

            placeholder(title: "Календарь", systemImage: "calendar")
                .tag(PrototypeTab.calendar)
                .tabItem {
                    Label {
                        Text(verbatim: "Календарь")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }

            placeholder(title: "Аналитика", systemImage: "chart.bar")
                .tag(PrototypeTab.analytics)
                .tabItem {
                    Label {
                        Text(verbatim: "Аналитика")
                    } icon: {
                        Image(systemName: "chart.bar")
                    }
                }
        }
    }

    private func placeholder(title: String, systemImage: String) -> some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text(verbatim: title)
                } icon: {
                    Image(systemName: systemImage)
                }
            }
        }
    }
}

private struct SubscriptionsIAPrototypeView: View {
    let variant: SubscriptionsIAPrototypeVariant

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var searchText = ""
    @State private var activeFilter: StatusFilter = .all
    @State private var sortOrder: SortOrder = .nextCharge
    @State private var showsAddDestination = false

    private var displayedItems: [PrototypeSubscription] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let scoped = PrototypeSubscription.fixtures.filter(activeFilter.includes)
        let searched = query.isEmpty
            ? scoped
            : scoped.filter { $0.title.localizedCaseInsensitiveContains(query) }

        switch sortOrder {
        case .nextCharge:
            return searched.sorted { $0.chargeOrder < $1.chargeOrder }
        case .name:
            return searched.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .amountAscending:
            return searched.sorted { $0.monthlyNormalizedRUB < $1.monthlyNormalizedRUB }
        case .amountDescending:
            return searched.sorted { $0.monthlyNormalizedRUB > $1.monthlyNormalizedRUB }
        case .recentlyAdded:
            return searched.sorted { $0.id > $1.id }
        }
    }

    private var monthlyTotal: Decimal {
        displayedItems
            .filter(\.status.countsInTotal)
            .reduce(.zero) { $0 + $1.monthlyNormalizedRUB }
    }

    var body: some View {
        Group {
            switch variant {
            case .nativeCollection:
                nativeCollection
                    .searchable(
                        text: $searchText,
                        placement: .automatic,
                        prompt: Text(verbatim: "Поиск подписок")
                    )
            case .compactEditorial:
                compactEditorialCollection
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: Text(verbatim: "Поиск подписок")
                    )
            case .searchFirst:
                searchFirstCollection
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text(verbatim: "Поиск подписок")
                    )
            }
        }
        .sheet(isPresented: $showsAddDestination) {
            NavigationStack {
                ContentUnavailableView {
                    Label {
                        Text(verbatim: "Добавление подписки")
                    } icon: {
                        Image(systemName: "plus.circle")
                    }
                }
                .navigationTitle(Text(verbatim: "Новая подписка"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            showsAddDestination = false
                        } label: {
                            Text(verbatim: "Готово")
                        }
                    }
                }
            }
        }
    }

    private var nativeCollection: some View {
        List {
            Section {
                rows
            } header: {
                summary
                    .textCase(nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text(verbatim: "Подписки"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                iconFilterMenu
                iconSortMenu
                addButton
            }
        }
    }

    private var compactEditorialCollection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    compactControls
                    summary
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .overlay(SoftClubColor.subtleSeparator.opacity(0.55))
                    .padding(.leading, 20)

                rowsWithInsetSeparators
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 12)
        }
        .padding(.bottom, 72)
        .background(SoftClubColor.canvas.ignoresSafeArea(edges: .bottom))
        .navigationTitle(Text(verbatim: "Подписки"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
        }
    }

    private var searchFirstCollection: some View {
        List {
            Section {
                rows
            } header: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        combinedControlsMenu
                        Spacer()
                    }
                    summary
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .navigationTitle(Text(verbatim: "Подписки"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                addButton
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        if displayedItems.isEmpty {
            noResults
        } else {
            ForEach(displayedItems) { item in
                rowLink(item)
            }
        }
    }

    @ViewBuilder
    private var rowsWithInsetSeparators: some View {
        if displayedItems.isEmpty {
            noResults
                .padding(.horizontal, 20)
        } else {
            ForEach(Array(displayedItems.enumerated()), id: \.element.id) { index, item in
                rowLink(item)
                    .padding(.horizontal, 20)

                if index < displayedItems.count - 1 {
                    Divider()
                        .overlay(SoftClubColor.subtleSeparator.opacity(0.55))
                        .padding(.leading, 72)
                }
            }
        }
    }

    private func rowLink(_ item: PrototypeSubscription) -> some View {
        NavigationLink {
            PrototypeSubscriptionDetail(item: item)
        } label: {
            PrototypeSubscriptionRow(item: item)
        }
        .buttonStyle(.plain)
    }

    private var noResults: some View {
        Text(verbatim: "Нет подписок для выбранного фильтра")
            .foregroundStyle(SoftClubColor.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .multilineTextAlignment(.center)
    }

    private var summary: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    summaryCount
                    summaryAmount
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    summaryCount
                    Spacer(minLength: 12)
                    summaryAmount
                }
            }
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(SoftClubColor.textSecondary)
        .accessibilityElement(children: .combine)
    }

    private var summaryCount: some View {
        Text(verbatim: "\(displayedItems.count) подписок")
    }

    @ViewBuilder
    private var summaryAmount: some View {
        if monthlyTotal > .zero {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(
                    monthlyTotal,
                    format: .currency(code: "RUB").precision(.fractionLength(0))
                )
                .monospacedDigit()

                Text(verbatim: "/ мес.")
            }
        }
    }

    @ViewBuilder
    private var compactControls: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                compactControlLayout
            }
        } else {
            compactControlLayout
        }
    }

    @ViewBuilder
    private var compactControlLayout: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                labeledFilterMenu
                labeledSortMenu
            }
        } else {
            HStack(spacing: 8) {
                labeledFilterMenu
                labeledSortMenu
                Spacer(minLength: 0)
            }
        }
    }

    private var addButton: some View {
        Button {
            showsAddDestination = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Добавить подписку")
    }

    private var iconFilterMenu: some View {
        Menu {
            filterActions
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .accessibilityLabel("Фильтр: \(activeFilter.title)")
    }

    private var iconSortMenu: some View {
        Menu {
            sortActions
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
        }
        .accessibilityLabel("Сортировка: \(sortOrder.title)")
    }

    private var labeledFilterMenu: some View {
        Menu {
            filterActions
        } label: {
            Label {
                Text(verbatim: activeFilter.title)
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
        .accessibilityLabel("Фильтр")
        .accessibilityValue(activeFilter.title)
    }

    private var labeledSortMenu: some View {
        Menu {
            sortActions
        } label: {
            Label {
                Text(verbatim: sortOrder.shortTitle)
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
        .accessibilityLabel("Сортировка")
        .accessibilityValue(sortOrder.title)
    }

    private var combinedControlsMenu: some View {
        Menu {
            Section {
                filterActions
            } header: {
                Text(verbatim: "Фильтр")
            }

            Section {
                sortActions
            } header: {
                Text(verbatim: "Сортировка")
            }
        } label: {
            Label {
                Text(verbatim: "\(activeFilter.title) · \(sortOrder.shortTitle)")
            } icon: {
                Image(systemName: "slider.horizontal.3")
            }
        }
    }

    @ViewBuilder
    private var filterActions: some View {
        ForEach(StatusFilter.allCases) { filter in
            Button {
                activeFilter = filter
            } label: {
                HStack {
                    Text(verbatim: filter.title)
                    if filter == activeFilter {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityAddTraits(filter == activeFilter ? .isSelected : [])
        }
    }

    @ViewBuilder
    private var sortActions: some View {
        ForEach(SortOrder.allCases) { order in
            Button {
                sortOrder = order
            } label: {
                HStack {
                    Text(verbatim: order.title)
                    if order == sortOrder {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .accessibilityAddTraits(order == sortOrder ? .isSelected : [])
        }
    }
}

private struct PrototypeSubscriptionRow: View {
    let item: PrototypeSubscription

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
        .accessibilityHint("Открыть управление подпиской")
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
        if let provider = ProviderCatalog.template(forProviderID: item.providerID) {
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
            Text(verbatim: item.nextCharge)
                .font(.footnote)
                .foregroundStyle(SoftClubColor.textSecondary)

            statusLabel
        }
    }

    private var amount: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text(
                item.amount,
                format: .currency(code: item.currencyCode).precision(.fractionLength(0...2))
            )
            .font(.body)
            .monospacedDigit()

            Text(verbatim: item.cycleLabel)
                .font(.footnote)
                .foregroundStyle(SoftClubColor.textSecondary.opacity(0.82))
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if let status = item.status.visibleMetadata {
            Label {
                Text(verbatim: status.title)
            } icon: {
                Image(systemName: status.systemImage)
            }
            .font(.caption)
            .foregroundStyle(SoftClubColor.textSecondary.opacity(0.9))
        }
    }
}

private struct PrototypeSubscriptionDetail: View {
    let item: PrototypeSubscription

    var body: some View {
        List {
            LabeledContent {
                Text(
                    item.amount,
                    format: .currency(code: item.currencyCode).precision(.fractionLength(0...2))
                )
            } label: {
                Text(verbatim: "Стоимость")
            }

            LabeledContent {
                Text(verbatim: item.nextCharge)
            } label: {
                Text(verbatim: "Следующее списание")
            }
        }
        .navigationTitle(Text(verbatim: item.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrototypeSubscription: Identifiable, Hashable {
    let id: Int
    let title: String
    let providerID: String
    let category: ItemCategory
    let amount: Decimal
    let currencyCode: String
    let cycleLabel: String
    let nextCharge: String
    let chargeOrder: Int
    let monthlyNormalizedRUB: Decimal
    let status: PrototypeStatus

    var accessibilityLabel: String {
        let amountText = amount.formatted(
            .currency(code: currencyCode)
                .precision(.fractionLength(0...2))
                .locale(Locale(identifier: "ru_RU"))
        )
        return [title, nextCharge, amountText, cycleLabel, status.visibleMetadata?.title]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    static let fixtures: [Self] = [
        Self(
            id: 1,
            title: "Spotify",
            providerID: "spotify",
            category: .music,
            amount: 199,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "11 сентября",
            chargeOrder: 11,
            monthlyNormalizedRUB: 199,
            status: .active
        ),
        Self(
            id: 2,
            title: "YouTube Premium",
            providerID: "youtube_premium",
            category: .video,
            amount: 299,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "14 сентября",
            chargeOrder: 14,
            monthlyNormalizedRUB: 299,
            status: .active
        ),
        Self(
            id: 3,
            title: "iCloud+",
            providerID: "icloud",
            category: .cloud,
            amount: 599,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "18 сентября",
            chargeOrder: 18,
            monthlyNormalizedRUB: 599,
            status: .active
        ),
        Self(
            id: 4,
            title: "Adobe Creative Cloud",
            providerID: "adobe_cc",
            category: .productivity,
            amount: 4_599,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "19 сентября",
            chargeOrder: 19,
            monthlyNormalizedRUB: 4_599,
            status: .active
        ),
        Self(
            id: 9,
            title: "Яндекс Плюс",
            providerID: "yandex_plus",
            category: .shopping,
            amount: 399,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "20 сентября",
            chargeOrder: 20,
            monthlyNormalizedRUB: .zero,
            status: .paused
        ),
        Self(
            id: 5,
            title: "GitHub Copilot",
            providerID: "github_copilot",
            category: .productivity,
            amount: 10,
            currencyCode: "USD",
            cycleLabel: "/ мес.",
            nextCharge: "21 сентября",
            chargeOrder: 21,
            monthlyNormalizedRUB: 907,
            status: .active
        ),
        Self(
            id: 6,
            title: "1Password Families",
            providerID: "1password",
            category: .productivity,
            amount: Decimal(string: "59.88") ?? 0,
            currencyCode: "USD",
            cycleLabel: "/ год",
            nextCharge: "24 сентября",
            chargeOrder: 24,
            monthlyNormalizedRUB: 459,
            status: .active
        ),
        Self(
            id: 7,
            title: "Microsoft 365 Family — расширенный семейный план",
            providerID: "microsoft_365",
            category: .productivity,
            amount: 1_199,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "27 сентября",
            chargeOrder: 27,
            monthlyNormalizedRUB: 1_199,
            status: .active
        ),
        Self(
            id: 8,
            title: "Apple Music",
            providerID: "apple_music",
            category: .music,
            amount: 169,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "29 сентября",
            chargeOrder: 29,
            monthlyNormalizedRUB: 169,
            status: .trial
        ),
        Self(
            id: 10,
            title: "Netflix",
            providerID: "netflix",
            category: .video,
            amount: 999,
            currencyCode: "RUB",
            cycleLabel: "/ мес.",
            nextCharge: "3 октября",
            chargeOrder: 33,
            monthlyNormalizedRUB: .zero,
            status: .archived
        ),
    ]
}

private enum PrototypeStatus: Hashable {
    case active
    case trial
    case paused
    case cancelled
    case archived

    var countsInTotal: Bool {
        self == .active || self == .trial
    }

    var visibleMetadata: (title: String, systemImage: String)? {
        switch self {
        case .active:
            nil
        case .trial:
            ("Пробный период", "hourglass")
        case .paused:
            ("На паузе", "pause.circle")
        case .cancelled:
            ("Отменена", "xmark.circle")
        case .archived:
            ("В архиве", "archivebox")
        }
    }
}

private enum StatusFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case trial
    case paused
    case cancelled
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Все"
        case .active: "Активные"
        case .trial: "Пробные"
        case .paused: "Пауза"
        case .cancelled: "Отменённые"
        case .archived: "Архив"
        }
    }

    func includes(_ item: PrototypeSubscription) -> Bool {
        switch self {
        case .all: item.status != .archived
        case .active: item.status == .active
        case .trial: item.status == .trial
        case .paused: item.status == .paused
        case .cancelled: item.status == .cancelled
        case .archived: item.status == .archived
        }
    }
}

private enum SortOrder: String, CaseIterable, Identifiable {
    case nextCharge
    case name
    case amountAscending
    case amountDescending
    case recentlyAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextCharge: "По дате списания"
        case .name: "По названию"
        case .amountAscending: "По цене ↑"
        case .amountDescending: "По цене ↓"
        case .recentlyAdded: "Недавно добавленные"
        }
    }

    var shortTitle: String {
        switch self {
        case .nextCharge: "По дате"
        case .name: "По названию"
        case .amountAscending: "Цена ↑"
        case .amountDescending: "Цена ↓"
        case .recentlyAdded: "Недавние"
        }
    }
}

private enum PrototypeTab: Hashable {
    case overview
    case subscriptions
    case calendar
    case analytics
}

#Preview("Subscriptions IA · A") {
    SubscriptionsIAPrototypeHost(variant: .nativeCollection)
}

#Preview("Subscriptions IA · B") {
    SubscriptionsIAPrototypeHost(variant: .compactEditorial)
}

#Preview("Subscriptions IA · C") {
    SubscriptionsIAPrototypeHost(variant: .searchFirst)
}
#endif
