import SwiftUI

// MARK: - Root View

/// App shell: context header + full-screen tab content + floating pill (pure nav).
/// Each screen owns its toolbar actions — no global floating "+" logic.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @State private var selectedTab: AppTab = .overview
    @State private var visitedTabs: Set<AppTab> = [.overview]
    @State private var activeSheet: ActiveSheet?

    /// Maximum width of the floating pill container (pill body + horizontal padding).
    /// Prevents the pill from spanning the full screen width on iPad and Mac.
    /// On any iPhone (max 430 pt wide) this cap is never reached.
    private let floatingPillMaxWidth: CGFloat = 440

    /// Binding that marks a tab as visited before switching to it, ensuring both
    /// state mutations land in the same render cycle (no blank-frame flicker).
    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { tab in
                visitedTabs.insert(tab)
                selectedTab = tab
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SorenContextBar(tab: selectedTab) { contextBarTrailing }

            ZStack {
                ForEach(AppTab.allCases) { tab in
                    // Opacity wrapper always exists — preserves crossfade animation.
                    // Content is created only on first visit and kept alive thereafter.
                    Group {
                        if visitedTabs.contains(tab) {
                            tabDestination(tab)
                        }
                    }
                    .opacity(selectedTab == tab ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: selectedTab)
                    .allowsHitTesting(selectedTab == tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SorenFloatingPill(selectedTab: tabBinding)
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xs)
                .frame(maxWidth: floatingPillMaxWidth)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .environment(\.addSubscriptionAction, AddSubscriptionAction { activeSheet = .addSubscription })
        .environment(\.navigateToItem, NavigateToItemAction { activeSheet = .itemDetails($0) })
        .sheet(item: $activeSheet, onDismiss: { container.itemsVersion += 1 }, content: sheetContent)
    }

    // MARK: - Tab Router

    @ViewBuilder
    private func tabDestination(_ tab: AppTab) -> some View {
        switch tab {
        case .overview:      HomeView()
        case .subscriptions: LibraryView()
        case .calendar:      CalendarView()
        case .insights:      AnalyticsView()
        }
    }

    // MARK: - Sheet Router

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .itemDetails(let item):
            NavigationStack {
                ItemDetailsView(
                    viewModel: ItemDetailsViewModel(
                        item: item,
                        repositories: container.repositories,
                        exchangeRateProvider: container.exchangeRateProvider
                    )
                )
            }
        case .addSubscription:
            NavigationStack {
                ProviderPickerView(
                    viewModel: AddSubscriptionViewModel(container: container)
                )
            }
        case .settings:
            SettingsSheetContent()
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
            activeSheet = .addSubscription
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ColorTokens.accent)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button { activeSheet = .settings } label: {
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

// MARK: - Active Sheet

private enum ActiveSheet: Identifiable {
    case itemDetails(RecurringItem)
    case addSubscription
    case settings

    var id: String {
        switch self {
        case .itemDetails(let item): "item-\(item.id.uuidString)"
        case .addSubscription:       "add"
        case .settings:              "settings"
        }
    }
}

// MARK: - Context Bar

/// Minimal top header: contextual title + per-tab trailing actions.
private struct SorenContextBar<Trailing: View>: View {
    let tab: AppTab
    @ViewBuilder let trailing: () -> Trailing

    private var contextTitle: String {
        switch tab {
        case .calendar:
            return _sorenMonthYearFormatter.string(from: .now).capitalized
        default:
            return tab.title
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(AppTab.allCases) { t in
                    let title = t == .calendar ? contextTitle : t.title
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
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
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
}

// MARK: - Settings Sheet Content

/// Root view of the Settings sheet window.
/// Owning `.preferredColorScheme` here — above the UINavigationController barrier —
/// ensures the sheet window's overrideUserInterfaceStyle updates live whenever
/// appState.appearanceMode changes while the sheet is open.
private struct SettingsSheetContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack { SettingsView() }
            .preferredColorScheme(appState.appearanceMode.colorScheme)
    }
}

// MARK: - Preview

#Preview {
    RootView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
