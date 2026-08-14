import SwiftUI

// Accessibility display values already start visually large. Scale their
// semantic roles deliberately across AX1...AX5 instead of applying the full
// body-text multiplier to every custom display size.
enum OverviewAccessibilityTypeScale {
    static func size(
        for dynamicTypeSize: DynamicTypeSize,
        accessibility1: CGFloat,
        accessibility3: CGFloat,
        accessibility5: CGFloat
    ) -> CGFloat {
        switch dynamicTypeSize {
        case .accessibility1:
            accessibility1
        case .accessibility2:
            (accessibility1 + accessibility3) / 2
        case .accessibility3:
            accessibility3
        case .accessibility4:
            (accessibility3 + accessibility5) / 2
        case .accessibility5:
            accessibility5
        default:
            accessibility1
        }
    }
}

// MARK: - Production Overview

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.addSubscriptionAction) private var addSubscription
    @Environment(\.navigateToItem) private var navigateToItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            VStack(alignment: .leading, spacing: 0) {
                OverviewHeader(
                    monthLabel: viewModel.monthLabel,
                    addAction: addSubscription
                )

                MonthlyPlanHeroView(presentation: viewModel.monthlyPlan)
                    .padding(.top, 12)

                if let insight = viewModel.overviewInsight {
                    OverviewInsightStageView(presentation: insight)
                        .padding(.top, 38)

                    UpcomingChargesSectionView(
                        presentation: viewModel.upcoming,
                        onSelectItem: { navigateToItem($0) }
                    )
                    .padding(.top, 36)
                } else {
                    UpcomingChargesSectionView(
                        presentation: viewModel.upcoming,
                        onSelectItem: { navigateToItem($0) }
                    )
                    .padding(.top, 38)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 56 : 16)
        }
        .scrollIndicators(.hidden)
        // Keep scrolled content inside the top safe-area-owned viewport. This
        // prevents large accessibility text from drawing below the status bar.
        .scrollClipDisabled(false)
        .clipped()
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let monthLabel: String
    let addAction: AddSubscriptionAction

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(verbatim: monthLabel)
                .font(monthFont)
                .tracking(1.20)
                .foregroundStyle(SoftClubColor.textSecondary)

            Spacer(minLength: 16)

            AddSubscriptionGlassControl(action: addAction)
        }
        .frame(height: 46)
    }

    private var monthFont: Font {
        if dynamicTypeSize.isAccessibilitySize {
            return .system(
                size: OverviewAccessibilityTypeScale.size(
                    for: dynamicTypeSize,
                    accessibility1: 14,
                    accessibility3: 15,
                    accessibility5: 16
                ),
                weight: .semibold
            )
        }
        return .system(size: 12.5, weight: .semibold)
    }
}

private struct AddSubscriptionGlassControl: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
        }
        .modifier(AddGlassModifier(
            forceOpaque: reduceTransparency || colorSchemeContrast == .increased
        ))
        .contentShape(.circle)
        .accessibilityLabel(String(localized: "Добавить подписку"))
    }
}

private struct AddGlassModifier: ViewModifier {
    let forceOpaque: Bool

    func body(content: Content) -> some View {
        if forceOpaque {
            content
                .buttonStyle(.plain)
                .background(SoftClubColor.glassControlSurface, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(SoftClubColor.subtleBorder, lineWidth: 0.8)
                }
        } else if #available(iOS 26, *) {
            content
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
                .buttonStyle(.plain)
                .background(.thinMaterial, in: Circle())
        }
    }
}

// MARK: - Monthly Plan Hero

private struct MonthlyPlanHeroView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var normalAmountSize: CGFloat = 47

    let presentation: MonthlyPlanHeroPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: presentation.title)
                .font(titleFont)
                .foregroundStyle(SoftClubColor.textSecondary)

            primary
                .padding(.top, 12)

            supportingContent
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 152, alignment: .leading)
        .modifier(OverviewAcrylicSurface(role: .hero))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    @ViewBuilder
    private var primary: some View {
        switch presentation.primaryStyle {
        case .financialValue:
            Text(verbatim: presentation.primary)
                .font(financialValueFont)
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .statement:
            Text(verbatim: presentation.primary)
                .font(statementFont)
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var supportingContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                leadingSupport
                trailingSupport
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                leadingSupport
                Spacer(minLength: 8)
                trailingSupport
            }
        }
    }

    private var leadingSupport: some View {
        Text(verbatim: presentation.leadingSupport)
            .font(supportFont.weight(.medium))
            .foregroundStyle(SoftClubColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var trailingSupport: some View {
        if let label = presentation.trailingSupportLabel,
           let value = presentation.trailingSupportValue {
            HStack(spacing: 4) {
                Text(verbatim: "\(label) ·")
                    .foregroundStyle(SoftClubColor.textTertiary)
                Text(verbatim: value)
                    .monospacedDigit()
                    .foregroundStyle(SoftClubColor.textSecondary)
            }
            .font(supportFont)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 16, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 18,
            accessibility3: 20,
            accessibility5: 22
        ))
    }

    private var financialValueFont: Font {
        // The normal 47 pt lock remains unchanged. At accessibility sizes the
        // semantic large-title curve scales the already-prominent value less
        // aggressively than scaling 47 pt linearly.
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: normalAmountSize, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 50,
            accessibility3: 54,
            accessibility5: 58
        ))
    }

    private var statementFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 26, weight: .medium)
        }
        return .system(
            size: OverviewAccessibilityTypeScale.size(
                for: dynamicTypeSize,
                accessibility1: 24,
                accessibility3: 27,
                accessibility5: 30
            ),
            weight: .medium
        )
    }

    private var supportFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 14, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 16,
            accessibility3: 18,
            accessibility5: 20
        ))
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
                            shape.fill(
                                SoftClubColor.secondaryCanvas.opacity(colorScheme == .dark ? 0.20 : 0.12)
                            )
                            shape
                                .fill(reflectedLight)
                                .blur(radius: 11)
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
        case (.hero, .light): SoftClubColor.elevatedSurface.opacity(0.90)
        case (.hero, .dark): SoftClubColor.elevatedSurface.opacity(0.86)
        case (.upcoming, .light): SoftClubColor.secondaryCanvas.opacity(0.38)
        case (.upcoming, .dark): SoftClubColor.surface.opacity(0.56)
        @unknown default: SoftClubColor.surface.opacity(0.82)
        }
    }

    private var materialOpacity: Double {
        switch (role, colorScheme) {
        case (.hero, _): 1
        case (.upcoming, .light): 0.54
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

    private var reflectedLight: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(colorScheme == .dark ? 0.04 : 0.07), location: 0.22),
                .init(
                    color: SoftClubColor.glassControlSurface.opacity(colorScheme == .dark ? 0.18 : 0.24),
                    location: 0.54
                ),
                .init(color: .white.opacity(colorScheme == .dark ? 0.06 : 0.10), location: 0.80),
                .init(color: .clear, location: 1),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private var polishedEdge: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(colorScheme == .dark ? 0.22 : 0.66), location: 0),
                .init(color: .white.opacity(colorScheme == .dark ? 0.07 : 0.20), location: 0.27),
                .init(color: .clear, location: 0.58),
                .init(
                    color: SoftClubColor.mutedSecondary.opacity(colorScheme == .dark ? 0.13 : 0.18),
                    location: 1
                ),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var edgeWidth: CGFloat {
        if colorSchemeContrast == .increased { return 1 }
        return role == .hero ? 0.65 : 0.38
    }

    private var shadowColor: Color {
        switch (role, colorScheme) {
        case (.hero, .light): .black.opacity(0.055)
        case (.hero, .dark): .black.opacity(0.24)
        case (.upcoming, .light): .black.opacity(0.018)
        case (.upcoming, .dark): .black.opacity(0.10)
        @unknown default: .clear
        }
    }

    private var shadowRadius: CGFloat { role == .hero ? 16 : 8 }
    private var shadowOffset: CGFloat { role == .hero ? 8 : 3 }
}

#Preview {
    HomeView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
        .environment(AppState())
}
