import SwiftUI

// MARK: - Production Overview

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @Environment(\.navigateToItem) private var navigateToItem

    @State private var viewModel: HomeViewModel?

    var body: some View {
        ZStack {
            SoftClubOverviewCanvas()
                .ignoresSafeArea()

            if let viewModel {
                content(viewModel)
            } else {
                LoadingStateView()
            }
        }
        .task(id: container.itemsVersion) {
            let viewModel: HomeViewModel
            if let existing = self.viewModel {
                viewModel = existing
            } else {
                let created = container.makeHomeViewModel()
                self.viewModel = created
                viewModel = created
            }
            await viewModel.load(forceReload: viewModel.isLoaded)
        }
    }

    @ViewBuilder
    private func content(_ viewModel: HomeViewModel) -> some View {
        if viewModel.hasError {
            ErrorStateView(
                message: "Не удалось загрузить данные",
                retryAction: {
                    Task { await viewModel.load(forceReload: true) }
                }
            )
        } else if !viewModel.isLoaded {
            LoadingStateView()
        } else {
            overview(viewModel)
        }
    }

    private func overview(_ viewModel: HomeViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                OverviewHeader(
                    monthLabel: viewModel.monthLabel,
                    addAction: addSubscription
                )
                .padding(.bottom, 16)

                MonthlyPlanHeroView(presentation: viewModel.monthlyPlan)

                if let insight = visibleAttention(from: viewModel.overviewInsight) {
                    OverviewInsightStageView(presentation: insight)
                        .padding(.top, 24)
                }

                if !viewModel.upcoming.rows.isEmpty {
                    UpcomingChargesSectionView(
                        presentation: viewModel.upcoming,
                        onSelectItem: { navigateToItem($0) }
                    )
                    .padding(
                        .top,
                        visibleAttention(from: viewModel.overviewInsight) == nil ? 30 : 26
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .defaultScrollAnchor(.top)
        .scrollIndicators(.hidden)
        .scrollClipDisabled(false)
        .clipped()
    }

    private func visibleAttention(
        from presentation: OverviewInsightPresentation?
    ) -> OverviewInsightPresentation? {
        guard let presentation else { return nil }
        switch presentation.kind {
        case .trialAttention, .sameDayAttention:
            return presentation
        case .annualScale, .denseWeek:
            return nil
        }
    }
}

// MARK: - Canvas and Header

private struct SoftClubOverviewCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        SoftClubColor.canvas
            .overlay {
                LinearGradient(
                    colors: [
                        Color.clear,
                        SoftClubColor.secondaryCanvas.opacity(colorScheme == .dark ? 0.30 : 0.27),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
    }
}

private struct OverviewHeader: View {
    let monthLabel: String
    let addAction: AddSubscriptionAction

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(verbatim: monthLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SoftClubColor.textSecondary)

            Spacer(minLength: 12)

            AddSubscriptionGlassControl(action: addAction)
        }
    }
}

private struct AddSubscriptionGlassControl: View {
    let action: AddSubscriptionAction

    var body: some View {
        Button {
            HapticEngine.selection()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .frame(width: 46, height: 46)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .softClubInteractiveGlass(in: Circle())
        .accessibilityLabel(String(localized: "Добавить подписку"))
    }
}

// MARK: - Monthly Plan Hero

private struct MonthlyPlanHeroView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var plannedAmountSize: CGFloat = 42

    let presentation: MonthlyPlanHeroPresentation

    var body: some View {
        Group {
            switch presentation.primaryStyle {
            case .financialValue:
                financialContent
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
            case .statement:
                statementContent
                    .padding(22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(OverviewAcrylicSurface(role: .hero))
        .accessibilityElement(children: .combine)
    }

    private var financialContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: presentation.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(SoftClubColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: presentation.primary)
                .font(plannedAmountFont)
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: presentation.leadingSupport)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let label = presentation.trailingSupportLabel,
                   let value = presentation.trailingSupportValue {
                    Text(verbatim: "\(label) \(value)")
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(SoftClubColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 16)
        }
    }

    private var statementContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: presentation.primary)
                .font(.title3.weight(.medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !presentation.leadingSupport.isEmpty {
                Text(verbatim: presentation.leadingSupport)
                    .font(.subheadline)
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var plannedAmountFont: Font {
        dynamicTypeSize.isAccessibilitySize
            ? .largeTitle.weight(.regular)
            : .system(size: plannedAmountSize, weight: .regular)
    }
}

// MARK: - Acrylic Surfaces

enum OverviewAcrylicSurfaceRole {
    case hero
    case upcoming

    var cornerRadius: CGFloat {
        switch self {
        case .hero: 22
        case .upcoming: 20
        }
    }
}

struct OverviewAcrylicSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let role: OverviewAcrylicSurfaceRole

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    if reduceTransparency {
                        shape.fill(opaqueFill)
                    } else {
                        shape
                            .fill(.ultraThinMaterial)
                            .opacity(materialOpacity)
                        shape.fill(materialFill)

                        if role == .hero {
                            shape.fill(monthlyTemperature)
                            shape
                                .fill(reflectedLight)
                                .blur(radius: colorScheme == .dark ? 11 : 8)
                                .clipShape(shape)
                        }
                    }

                    shape.strokeBorder(polishedEdge, lineWidth: edgeWidth)
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
    }

    private var materialFill: Color {
        switch (role, colorScheme) {
        case (.hero, .light): SoftClubColor.elevatedSurface.opacity(0.68)
        case (.hero, .dark): SoftClubColor.elevatedSurface.opacity(0.86)
        case (.upcoming, .light): SoftClubColor.secondaryCanvas.opacity(0.48)
        case (.upcoming, .dark): SoftClubColor.surface.opacity(0.56)
        @unknown default: SoftClubColor.surface.opacity(0.82)
        }
    }

    private var materialOpacity: Double {
        switch (role, colorScheme) {
        case (.hero, _): 1
        case (.upcoming, .light): 0.68
        case (.upcoming, .dark): 0.58
        @unknown default: 1
        }
    }

    private var opaqueFill: Color {
        switch role {
        case .hero: SoftClubColor.elevatedSurface
        case .upcoming: SoftClubColor.surface
        }
    }

    private var monthlyTemperature: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    SoftClubColor.secondaryCanvas.opacity(0.20),
                    SoftClubColor.secondaryCanvas.opacity(0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            stops: [
                .init(color: .white.opacity(0.22), location: 0),
                .init(color: SoftClubColor.glassControlSurface.opacity(0.12), location: 0.28),
                .init(color: SoftClubColor.secondaryCanvas.opacity(0.26), location: 0.64),
                .init(color: SoftClubColor.mutedSecondary.opacity(0.10), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var reflectedLight: LinearGradient {
        LinearGradient(
            stops: [
                .init(
                    color: colorScheme == .dark
                        ? .clear
                        : SoftClubColor.mutedSecondary.opacity(0.08),
                    location: 0
                ),
                .init(color: .white.opacity(colorScheme == .dark ? 0.04 : 0.14), location: 0.22),
                .init(
                    color: SoftClubColor.glassControlSurface.opacity(colorScheme == .dark ? 0.18 : 0.30),
                    location: 0.54
                ),
                .init(color: .white.opacity(colorScheme == .dark ? 0.06 : 0.14), location: 0.80),
                .init(color: .clear, location: 1),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private var polishedEdge: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(colorScheme == .dark ? 0.22 : 0.76), location: 0),
                .init(color: .white.opacity(colorScheme == .dark ? 0.07 : 0.24), location: 0.27),
                .init(color: .clear, location: 0.58),
                .init(
                    color: SoftClubColor.mutedSecondary.opacity(colorScheme == .dark ? 0.13 : 0.22),
                    location: 1
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var edgeWidth: CGFloat {
        guard colorSchemeContrast != .increased else { return 1 }

        switch (role, colorScheme) {
        case (.hero, .light): return 0.78
        case (.hero, .dark): return 0.65
        case (.upcoming, .light): return 0.48
        case (.upcoming, .dark): return 0.38
        @unknown default: return 0.65
        }
    }

    private var shadowColor: Color {
        switch (role, colorScheme) {
        case (.hero, .light): .black.opacity(0.032)
        case (.hero, .dark): .black.opacity(0.24)
        case (.upcoming, .light): .black.opacity(0.03)
        case (.upcoming, .dark): .black.opacity(0.10)
        @unknown default: .clear
        }
    }

    private var shadowRadius: CGFloat {
        switch (role, colorScheme) {
        case (.hero, .light): 11
        case (.hero, .dark): 16
        case (.upcoming, .light): 7
        case (.upcoming, .dark): 8
        @unknown default: 8
        }
    }

    private var shadowOffset: CGFloat {
        switch (role, colorScheme) {
        case (.hero, .light): 4
        case (.hero, .dark): 8
        case (.upcoming, _): 3
        @unknown default: 3
        }
    }
}

#Preview {
    HomeView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
        .environment(AppState())
}
