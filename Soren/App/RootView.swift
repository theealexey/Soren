import SwiftUI

// MARK: - Root View

/// App shell: minimal context header + full-screen tab content + floating pill nav.
/// Native TabView replaced with opacity-based switching so each tab's
/// NavigationStack and ViewModel state stay alive across tab changes.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: AppTab = .home
    @State private var showAddSheet = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            SorenContextBar(tab: selectedTab) {
                showSettings = true
            }

            ZStack {
                ForEach(AppTab.allCases) { tab in
                    tab.destination
                        .opacity(selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(selectedTab == tab)
                        .animation(.easeInOut(duration: 0.16), value: selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ColorTokens.background)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SorenFloatingPill(selectedTab: $selectedTab) {
                showAddSheet = true
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.xs)
        }
        .environment(\.addSubscriptionAction, AddSubscriptionAction { showAddSheet = true })
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
        }
    }
}

// MARK: - Context Bar

/// Minimal top header: contextual title for the active tab + settings gear.
private struct SorenContextBar: View {
    let tab: AppTab
    let settingsAction: () -> Void

    private var contextTitle: String {
        guard tab == .home else { return tab.title }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ru_RU")
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: .now).capitalized
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .leading) {
                ForEach(AppTab.allCases) { t in
                    Text(t == .home ? contextTitle : t.title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .opacity(tab == t ? 1 : 0)
                        .scaleEffect(tab == t ? 1 : 0.94, anchor: .leading)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: tab)

            Spacer()

            Button(action: settingsAction) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background {
            ColorTokens.surface
                .overlay(alignment: .bottom) {
                    ColorTokens.separator
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }
}

// MARK: - Floating Pill

/// Capsule nav bar that floats above the bottom safe area.
/// Left section: 5 tab icons. Right section: add-subscription "+" button.
private struct SorenFloatingPill: View {
    @Binding var selectedTab: AppTab
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Tab icons — fill available width evenly
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
            }
            .frame(maxWidth: .infinity)

            // Hairline divider
            Rectangle()
                .fill(ColorTokens.separator)
                .frame(width: 0.5, height: 22)
                .padding(.horizontal, Spacing.sm)

            // Add button
            Button(action: {
                HapticEngine.selection()
                onAdd()
            }) {
                ZStack {
                    Circle()
                        .fill(ColorTokens.accent)
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, Spacing.xs)
        }
        .padding(.leading, Spacing.xs)
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

struct AddSubscriptionAction: @unchecked Sendable {
    let trigger: () -> Void
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

// MARK: - Tab Definition

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case library
    case calendar
    case analytics
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:      String(localized: "Главная")
        case .library:   String(localized: "Подписки")
        case .calendar:  String(localized: "Календарь")
        case .analytics: String(localized: "Аналитика")
        case .alerts:    String(localized: "Алерты")
        }
    }

    var icon: String {
        switch self {
        case .home:      "house"
        case .library:   "list.bullet"
        case .calendar:  "calendar"
        case .analytics: "chart.bar"
        case .alerts:    "bell"
        }
    }

    var activeIcon: String {
        switch self {
        case .home:      "house.fill"
        case .library:   "list.bullet"
        case .calendar:  "calendar"
        case .analytics: "chart.bar.fill"
        case .alerts:    "bell.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .home:      HomeView()
        case .library:   LibraryView()
        case .calendar:  CalendarPlaceholderView()
        case .analytics: AnalyticsPlaceholderView()
        case .alerts:    AlertsView()
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
