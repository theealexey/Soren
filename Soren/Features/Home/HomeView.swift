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
            if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 0) {
                    overviewZones(viewModel)
                }
            } else {
                overviewZones(viewModel)
            }
        }
        .defaultScrollAnchor(.top)
        .scrollIndicators(.hidden)
    }

    private func overviewZones(_ viewModel: HomeViewModel) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            OverviewHeader(monthLabel: viewModel.monthLabel, addAction: addSubscription)
                .padding(.bottom, 16)

            MonthlyPlanHeroView(
                presentation: viewModel.monthlyPlan,
                monthSchedule: viewModel.monthSchedule
            )

            UpcomingChargesSectionView(
                presentation: viewModel.upcoming,
                onSelectItem: { navigateToItem($0) }
            )
            .padding(.top, 24)

            OverviewStatusTiles(counts: viewModel.statusCounts)
                .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }
}

// MARK: - Canvas and Header

private struct SoftClubOverviewCanvas: View {
    var body: some View {
        SoftClubColor.canvas
    }
}

private struct OverviewHeader: View {
    let monthLabel: String
    let addAction: AddSubscriptionAction

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(verbatim: monthLabel)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            AddSubscriptionGlassControl(action: addAction)
        }
        .frame(minHeight: 48)
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
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .softClubInteractiveGlass(in: Circle())
        .accessibilityLabel(String(localized: "Добавить подписку"))
    }
}

// MARK: - Monthly Plan Hero

private struct MonthlyPlanHeroView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var plannedAmountSize: CGFloat = 46
    @ScaledMetric(relativeTo: .subheadline) private var labelSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var countSize: CGFloat = 16

    let presentation: MonthlyPlanHeroPresentation
    let monthSchedule: MonthSchedulePresentation?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch presentation.primaryStyle {
            case .financialValue:
                financialContent
            case .statement:
                statementContent
            }

            Spacer(minLength: 20)

            if let monthSchedule {
                MonthScheduleRailView(presentation: monthSchedule)
            }
        }
        .frame(minHeight: 170, alignment: .topLeading)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(OverviewGlassSurface(cornerRadius: 28, opaqueColor: SoftClubColor.elevatedSurface))
    }

    private var financialContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: presentation.title)
                .font(.system(size: labelSize, weight: .semibold))
                .foregroundStyle(SoftClubColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: presentation.primary)
                .font(.system(size: plannedAmountSize, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text(verbatim: presentation.leadingSupport)
                .font(.system(size: countSize))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Passive Overview Surfaces

struct OverviewGlassSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let cornerRadius: CGFloat
    let opaqueColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency || colorSchemeContrast == .increased {
            content
                .background(opaqueColor, in: shape)
                .overlay { shape.strokeBorder(SoftClubColor.subtleBorder, lineWidth: 1) }
        } else if #available(iOS 26, *) {
            content
                .glassEffect(
                    colorScheme == .light
                        ? .regular.tint(SoftClubColor.secondaryCanvas)
                        : .regular,
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay { shape.strokeBorder(SoftClubColor.subtleBorder, lineWidth: 0.5) }
        } else {
            content
                .background(.thinMaterial, in: shape)
                .overlay { shape.strokeBorder(SoftClubColor.subtleBorder, lineWidth: 0.5) }
        }
    }
}

// MARK: - Subscription State

private struct OverviewStatusTiles: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let counts: SubscriptionStatusCounts?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) { tiles }
            } else {
                HStack(spacing: 12) { tiles }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var tiles: some View {
        OverviewStatusTile(label: String(localized: "Активные"), count: counts?.active)
        OverviewStatusTile(label: String(localized: "Пробные"), count: counts?.trial)
        OverviewStatusTile(
            label: String(localized: "На паузе"),
            count: counts?.paused,
            hasRedEdge: true
        )
    }
}

private struct OverviewStatusTile: View {
    @ScaledMetric(relativeTo: .subheadline) private var labelSize: CGFloat = 14
    @ScaledMetric(relativeTo: .title) private var countSize: CGFloat = 30

    let label: String
    let count: Int?
    var hasRedEdge = false

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: label)
                    .font(.system(size: labelSize))
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)

                Text(verbatim: count.map { $0.formatted() } ?? "—")
                    .font(.system(size: countSize, weight: .regular))
                    .monospacedDigit()
                    .foregroundStyle(SoftClubColor.textPrimary)
            }

            if hasRedEdge {
                RoundedRectangle(cornerRadius: 1)
                    .fill(SoftClubColor.signatureRed)
                    .frame(width: 2, height: 44)
                    .offset(x: -8)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(16)
        .modifier(OverviewGlassSurface(cornerRadius: 20, opaqueColor: SoftClubColor.surface))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            count.map { "\(label), \($0.formatted())" }
                ?? "\(label), \(String(localized: "Нет данных"))"
        )
    }
}

#Preview {
    HomeView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
        .environment(AppState())
}
