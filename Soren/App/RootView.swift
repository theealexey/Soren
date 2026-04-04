import SwiftUI

// MARK: - Root View

/// App shell: context header + full-screen tab content + floating pill (pure nav).
/// Each screen owns its toolbar actions — no global floating "+" logic.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @AppStorage("soren.appearanceMode") private var appearanceModeRaw = AppearanceMode.system.rawValue
    @State private var selectedTab: AppTab = .overview
    @State private var showAddSheet = false
    @State private var showSettings = false
    @State private var selectedItem: RecurringItem?

    private var preferredColorScheme: ColorScheme? {
        AppearanceMode(rawValue: appearanceModeRaw)?.colorScheme
    }

    var body: some View {
        VStack(spacing: 0) {
            SorenContextBar(tab: selectedTab) { contextBarTrailing }

            ZStack {
                ForEach(AppTab.allCases) { tab in
                    tab.destination
                        .opacity(selectedTab == tab ? 1 : 0)
                        .animation(.easeInOut(duration: 0.16), value: selectedTab)
                        .allowsHitTesting(selectedTab == tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SorenFloatingPill(selectedTab: $selectedTab)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xs)
        }
        .environment(\.addSubscriptionAction, AddSubscriptionAction { showAddSheet = true })
        .environment(\.navigateToItem, NavigateToItemAction { selectedItem = $0 })
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                ItemDetailsView(
                    viewModel: ItemDetailsViewModel(
                        item: item,
                        repositories: container.repositories
                    )
                )
            }
        }
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                ProviderPickerView(
                    viewModel: AddSubscriptionViewModel(container: container)
                )
            }
        }
        .onChange(of: showAddSheet) { _, isShowing in
            if !isShowing { container.itemsVersion += 1 }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
                .preferredColorScheme(preferredColorScheme)
        }
    }

    // MARK: - Per-tab trailing actions

    @ViewBuilder
    private var contextBarTrailing: some View {
        switch selectedTab {
        case .overview:
            HStack(spacing: Spacing.xxs) {
                addButton
                settingsButton
            }
        case .subscriptions:
            addButton
        case .calendar, .insights:
            EmptyView()
        }
    }

    private var addButton: some View {
        Button {
            HapticEngine.selection()
            showAddSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ColorTokens.accent)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

// Allocated once at file scope — static stored properties are not allowed in generic types.
// DateFormatter is expensive (~1ms) to create; keeping one instance eliminates per-render cost.
private let _sorenMonthYearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ru_RU")
    f.dateFormat = "LLLL yyyy"
    return f
}()

// MARK: - Context Bar

/// Minimal top header: contextual title + per-tab trailing actions.
private struct SorenContextBar<Trailing: View>: View {
    let tab: AppTab
    @ViewBuilder let trailing: () -> Trailing

    private var contextTitle: String {
        switch tab {
        case .overview, .calendar:
            return _sorenMonthYearFormatter.string(from: .now).capitalized
        default:
            return tab.title
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(AppTab.allCases) { t in
                    let title = (t == .overview || t == .calendar) ? contextTitle : t.title
                    Text(verbatim: title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .opacity(tab == t ? 1 : 0)
                        .scaleEffect(tab == t ? 1 : 0.94, anchor: .leading)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)

            Spacer()

            trailing()
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .animation(.easeInOut(duration: 0.18), value: tab)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            ColorTokens.surface
                .overlay(alignment: .bottom) {
                    ColorTokens.separator.frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Floating Pill (pure navigator)

/// Capsule tab switcher — no business logic, no "+" button.
/// 4 icons only: Overview · Subscriptions · Calendar · Insights.
private struct SorenFloatingPill: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(ColorTokens.separator.opacity(0.5), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 6)
        .shadow(color: .black.opacity(0.05), radius: 4,  x: 0, y: 2)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(MotionTokens.snappy) { selectedTab = tab }
            HapticEngine.selection()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isActive ? tab.activeIcon : tab.icon)
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.textTertiary)
                    .frame(height: 20)

                Circle()
                    .fill(isActive ? ColorTokens.accent : Color.clear)
                    .frame(width: 3.5, height: 3.5)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - AddSubscription Environment Action

@MainActor
struct AddSubscriptionAction: Sendable {
    let trigger: @MainActor () -> Void
    func callAsFunction() { trigger() }
}

private struct AddSubscriptionActionKey: EnvironmentKey {
    static let defaultValue = AddSubscriptionAction(trigger: {})
}

extension EnvironmentValues {
    var addSubscriptionAction: AddSubscriptionAction {
        get { self[AddSubscriptionActionKey.self] }
        set { self[AddSubscriptionActionKey.self] = newValue }
    }
}

// MARK: - NavigateToItem Environment Action

@MainActor
struct NavigateToItemAction: Sendable {
    let trigger: @MainActor (RecurringItem) -> Void
    func callAsFunction(_ item: RecurringItem) { trigger(item) }
}

private struct NavigateToItemActionKey: EnvironmentKey {
    static let defaultValue = NavigateToItemAction(trigger: { _ in })
}

extension EnvironmentValues {
    var navigateToItem: NavigateToItemAction {
        get { self[NavigateToItemActionKey.self] }
        set { self[NavigateToItemActionKey.self] = newValue }
    }
}

// MARK: - Tab Definition

enum AppTab: String, CaseIterable, Identifiable {
    case overview
    case subscriptions
    case calendar
    case insights

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:      String(localized: "Обзор")
        case .subscriptions: String(localized: "Подписки")
        case .calendar:      String(localized: "Календарь")
        case .insights:      String(localized: "Аналитика")
        }
    }

    var icon: String {
        switch self {
        case .overview:      "house"
        case .subscriptions: "list.bullet"
        case .calendar:      "calendar"
        case .insights:      "chart.bar"
        }
    }

    var activeIcon: String {
        switch self {
        case .overview:      "house.fill"
        case .subscriptions: "list.bullet"
        case .calendar:      "calendar"
        case .insights:      "chart.bar.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .overview:      HomeView()
        case .subscriptions: LibraryView()
        case .calendar:      CalendarView()
        case .insights:      AnalyticsView()
        }
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
