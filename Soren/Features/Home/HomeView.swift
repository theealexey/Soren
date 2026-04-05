import SwiftUI

// MARK: - Home View (Billing Landscape)

/// Foresight screen: 30-day billing landscape, next-payment callout, and quiet/peak insights.
/// Answers: what's coming, when, and how much pressure does this month carry.
///
/// ViewModel is created via AppContainer factory and lives as @State — survives
/// tab switches without rebuilding, refreshes on itemsVersion changes.
struct HomeView: View {

    @Environment(AppContainer.self) private var container
    @Environment(\.appTheme) private var theme
    @Environment(\.addSubscriptionAction) private var addSubscription

    @State private var viewModel: HomeViewModel?

    // MARK: - Body

    var body: some View {
        ZStack {
            theme.screenBackground.ignoresSafeArea()

            if let vm = viewModel {
                content(vm)
            } else {
                LoadingStateView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            let vm = container.makeHomeViewModel()
            vm.load()
            viewModel = vm
        }
        .onChange(of: container.itemsVersion) { _, _ in
            viewModel?.load(forceReload: true)
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private func content(_ vm: HomeViewModel) -> some View {
        if vm.hasError {
            ErrorStateView(
                message: "Couldn't load data",
                retryAction: { vm.load(forceReload: true) }
            )
        } else if !vm.isLoaded {
            LoadingStateView()
        } else {
            landscapeScreen(vm)
        }
    }

    // MARK: - Landscape Screen

    private func landscapeScreen(_ vm: HomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                HomeHeaderView(
                    monthLabel: vm.monthLabel,
                    forecastLabel: vm.forecastLabel
                )
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.lg)

                BillingLandscapeContainerView(
                    points: vm.landscapePoints,
                    selection: vm.selection,
                    onSelectDate: { vm.selectDate($0) }
                )

                NextPaymentCalloutView(state: vm.callout)
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, Spacing.xxl)

                if !vm.insights.isEmpty {
                    InsightSectionView(insights: vm.insights)
                        .padding(.bottom, Spacing.xl)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
        .environment(AppState())
}
