import SwiftUI

// MARK: - Root View

/// App shell: custom top nav (tabs) + tab content + bottom add-subscription CTA.
/// Native TabView is replaced with opacity-based switching so each tab's
/// NavigationStack (and its ViewModel state) stays alive across tab changes.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: AppTab = .home
    @State private var showAddSheet = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            SorenTopBar(selectedTab: $selectedTab) {
                showSettings = true
            }

            // Each tab stays rendered — opacity keeps state alive
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
            SorenAddBar {
                showAddSheet = true
            }
        }
        // Global add sheet — triggered from bar or from empty-state views
        .environment(\.addSubscriptionAction, AddSubscriptionAction { showAddSheet = true })
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                ProviderPickerView(
                    viewModel: AddSubscriptionViewModel(container: container)
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsView() }
        }
    }
}

// MARK: - Top Bar

/// Custom navigation bar: wordmark left · tab icons center-right · gear far right.
private struct SorenTopBar: View {
    @Binding var selectedTab: AppTab
    let settingsAction: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Wordmark
            Text("SOREN")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(ColorTokens.accent)

            Spacer()

            // Tab icons
            HStack(spacing: Spacing.xs) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
            }

            // Settings
            Button(action: settingsAction) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.leading, Spacing.xs)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background {
            ColorTokens.surface
                .overlay(alignment: .bottom) {
                    ColorTokens.separator
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab

        return Button {
            withAnimation(MotionTokens.snappy) {
                selectedTab = tab
            }
            HapticEngine.selection()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isActive ? tab.activeIcon : tab.icon)
                    .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? ColorTokens.accent : ColorTokens.textTertiary)
                    .frame(width: 28, height: 20)

                // Active indicator dot
                Circle()
                    .fill(isActive ? ColorTokens.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.16), value: isActive)
    }
}

// MARK: - Bottom Add Bar

/// Full-width bottom CTA that launches the add-subscription flow.
private struct SorenAddBar: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ColorTokens.separator
                .frame(height: 0.5)

            Button(action: action) {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Text("Добавить подписку")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [ColorTokens.accent, ColorTokens.accent.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: CornerRadius.large)
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.plain)
        }
        .background(ColorTokens.surface.ignoresSafeArea(edges: .bottom))
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
