import SwiftUI

struct RootView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                tab.destination
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
        .tint(ColorTokens.accent)
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
        case .home:      "house.fill"
        case .library:   "list.bullet"
        case .calendar:  "calendar"
        case .analytics: "chart.bar.fill"
        case .alerts:    "bell.badge.fill"
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

#Preview {
    RootView()
}
