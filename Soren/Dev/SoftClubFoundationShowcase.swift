#if DEBUG
import SwiftUI

fileprivate enum OverviewInsightFixture {
    case annualScale
    case attention
    case denseWeek

    var eyebrow: String {
        switch self {
        case .annualScale: "ГОДОВОЙ МАСШТАБ"
        case .attention: "НА КОНТРОЛЕ"
        case .denseWeek: "ПЛОТНАЯ НЕДЕЛЯ"
        }
    }

    var primary: String {
        switch self {
        case .annualScale: "149 880 ₽"
        case .attention: "Пробный период заканчивается через 3 дня"
        case .denseWeek: "3 списания за 7 дней"
        }
    }

    var supporting: String {
        switch self {
        case .annualScale: "при текущем наборе подписок"
        case .attention: "Apple Music · затем 169 ₽ / мес."
        case .denseWeek: "797 ₽ · 11–18 августа"
        }
    }

    var usesFinancialValueStyle: Bool {
        self == .annualScale
    }

    var accessibilityValue: String {
        switch self {
        case .annualScale:
            "149 880 рублей в год при текущем наборе подписок"
        case .attention:
            "Пробный период Apple Music заканчивается через 3 дня, затем 169 рублей в месяц"
        case .denseWeek:
            "3 списания на сумму 797 рублей с 11 по 18 августа"
        }
    }
}

/// Isolated, deterministic implementation of the Soren Overview master design lock.
/// Production state, navigation, persistence, and notification services are intentionally absent.
struct DesignLockPrototypeView: View {
    private let insight: OverviewInsightFixture

    init() {
        insight = .annualScale
    }

    fileprivate init(insight: OverviewInsightFixture) {
        self.insight = insight
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OverviewDesignLockHeader()

                    MonthlySpendingHero()
                        .padding(.top, 12)

                    OverviewInsightStage(insight: insight)
                        .padding(.top, 38)

                    UpcomingChargesSection()
                        .padding(.top, 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            SorenDesignLockTabBar()
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 7)
        }
        .background {
            DesignLockCanvas()
                .ignoresSafeArea()
        }
    }
}

// MARK: - Canvas and Header

private struct DesignLockCanvas: View {
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

private struct OverviewDesignLockHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 6) {
                Text(verbatim: "АВГУСТ 2026")
                    .font(.system(size: 12.5, weight: .semibold))
                    .tracking(1.20)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8.5, weight: .semibold))
            }
            .foregroundStyle(SoftClubColor.textSecondary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Август 2026, выбрать месяц")

            Spacer(minLength: 16)

            AddSubscriptionGlassControl()
        }
        .frame(height: 46)
    }
}

private struct AddSubscriptionGlassControl: View {
    @Environment(\.designLockForceOpaqueMaterials) private var forceOpaqueMaterials

    var body: some View {
        Button(action: {}) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .frame(width: 46, height: 46)
        }
        .modifier(DesignLockAddGlassModifier(forceOpaque: forceOpaqueMaterials))
        .contentShape(.circle)
        .accessibilityLabel("Добавить подписку")
    }
}

private struct DesignLockAddGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.designLockForceIncreasedContrast) private var forceIncreasedContrast

    let forceOpaque: Bool

    func body(content: Content) -> some View {
        if forceOpaque || reduceTransparency || colorSchemeContrast == .increased || forceIncreasedContrast {
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
                .glassEffect(
                    .regular.interactive(),
                    in: .circle
                )
        } else {
            content
                .buttonStyle(.plain)
                .background(.thinMaterial, in: Circle())
        }
    }
}

// MARK: - Monthly Spending Hero

private struct MonthlySpendingHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 45

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Расходы за август")
                .font(.system(size: 15.5, weight: .regular))
                .foregroundStyle(SoftClubColor.textSecondary)

            Text(verbatim: "12 490 ₽")
                .font(.system(size: amountSize, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .padding(.top, 12)
                .accessibilityLabel("Расходы за август: 12 490 рублей")

            supportingContent
                .padding(.top, 16)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 152, alignment: .leading)
        .modifier(DesignLockAcrylicSurface(role: .hero))
    }

    @ViewBuilder
    private var supportingContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                trend
                forecast
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                trend
                Spacer(minLength: 8)
                forecast
            }
        }
    }

    private var trend: some View {
        Text(verbatim: "↓ 8,4% к июлю")
            .font(.system(size: 13.5, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(SoftClubColor.success)
            .lineLimit(1)
    }

    private var forecast: some View {
        HStack(spacing: 0) {
            Text(verbatim: "Прогноз · ")
                .foregroundStyle(SoftClubColor.textTertiary)
            Text(verbatim: "15 960 ₽")
                .fontWeight(.medium)
                .foregroundStyle(SoftClubColor.textSecondary)
                .monospacedDigit()
        }
        .font(.system(size: 13.5, weight: .regular))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Прогноз: 15 960 рублей")
    }
}

// MARK: - Editorial Insight Stage

private struct OverviewInsightStage: View {
    @ScaledMetric(relativeTo: .largeTitle) private var financialValueSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title2) private var statementSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var eyebrowSize: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var supportingSize: CGFloat = 14

    let insight: OverviewInsightFixture

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            register
                .padding(.top, 25)

            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: insight.eyebrow)
                    .font(.system(size: eyebrowSize, weight: .medium))
                    .tracking(0.85)
                    .foregroundStyle(SoftClubColor.textTertiary)

                primaryContent

                Text(verbatim: insight.supporting)
                    .font(.system(size: supportingSize, weight: .regular))
                    .foregroundStyle(SoftClubColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(insight.eyebrow)
        .accessibilityValue(insight.accessibilityValue)
    }

    @ViewBuilder
    private var primaryContent: some View {
        if insight.usesFinancialValueStyle {
            Text(verbatim: insight.primary)
                .font(.system(size: financialValueSize, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
        } else {
            Text(verbatim: insight.primary)
                .font(.system(size: statementSize, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var register: some View {
        RoundedRectangle(cornerRadius: 0.8, style: .continuous)
            .fill(SoftClubColor.signatureRed)
            .frame(width: 2, height: 24)
            .accessibilityHidden(true)
    }
}

// MARK: - Upcoming Charges

private struct UpcomingChargesSection: View {
    private let charges = UpcomingCharge.fixtures

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DesignLockSectionHeader(
                title: "Ближайшие списания",
                metadata: "3 · 3 470 ₽"
            )

            VStack(spacing: 0) {
                ForEach(Array(charges.enumerated()), id: \.element.id) { index, charge in
                    UpcomingChargeRow(charge: charge)

                    if index < charges.count - 1 {
                        Rectangle()
                            .fill(SoftClubColor.subtleSeparator)
                            .frame(height: 0.5)
                            .opacity(0.72)
                            .padding(.leading, 54)
                            .padding(.trailing, 14)
                    }
                }
            }
            .modifier(DesignLockAcrylicSurface(role: .upcoming))
        }
    }
}

private struct UpcomingChargeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let charge: UpcomingCharge

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            ProviderArtwork(charge: charge)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    providerIdentity
                    amountAndDate
                }
            } else {
                providerIdentity
                Spacer(minLength: 8)
                amountAndDate
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 11 : 9)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 86 : 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(charge.title), \(charge.plan), \(charge.amount), \(charge.date)"
        )
    }

    private var providerIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: charge.title)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            Text(verbatim: charge.plan)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(SoftClubColor.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountAndDate: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text(verbatim: charge.amount)
                .font(.system(size: 17, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)

            Text(verbatim: charge.date)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(SoftClubColor.textTertiary)
        }
    }
}

private struct ProviderArtwork: View {
    let charge: UpcomingCharge

    var body: some View {
        Image(charge.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: charge.innerArtworkSize, height: charge.innerArtworkSize)
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 10))
            .accessibilityHidden(true)
    }
}

private struct UpcomingCharge: Identifiable {
    let id: String
    let title: String
    let plan: String
    let amount: String
    let date: String
    let assetName: String
    let innerArtworkSize: CGFloat

    static let fixtures = [
        UpcomingCharge(
            id: "spotify",
            title: "Spotify",
            plan: "Индивидуальный",
            amount: "199 ₽",
            date: "11 августа",
            assetName: "provider_spotify",
            innerArtworkSize: 30
        ),
        UpcomingCharge(
            id: "youtube-premium",
            title: "YouTube Premium",
            plan: "Индивидуальный",
            amount: "299 ₽",
            date: "14 августа",
            assetName: "provider_youtube_premium",
            innerArtworkSize: 39
        ),
        UpcomingCharge(
            id: "icloud",
            title: "iCloud+",
            plan: "200 ГБ",
            amount: "299 ₽",
            date: "18 августа",
            assetName: "provider_icloud",
            innerArtworkSize: 44
        ),
    ]
}

// MARK: - Shared Presentation

private struct DesignLockSectionHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let metadata: String

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                titleText
                metadataText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                titleText
                Spacer(minLength: 8)
                metadataText
            }
        }
    }

    private var titleText: some View {
        Text(verbatim: title)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(SoftClubColor.textPrimary)
            .lineLimit(1)
            .layoutPriority(1)
    }

    private var metadataText: some View {
        Text(verbatim: metadata)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(SoftClubColor.textTertiary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private enum DesignLockSurfaceRole {
    case hero
    case upcoming

    var cornerRadius: CGFloat {
        switch self {
        case .hero: 22
        case .upcoming: 20
        }
    }
}

private struct DesignLockAcrylicSurface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.designLockForceOpaqueMaterials) private var forceOpaqueMaterials
    @Environment(\.designLockForceIncreasedContrast) private var forceIncreasedContrast

    let role: DesignLockSurfaceRole

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: role.cornerRadius, style: .continuous)

        content
            .background {
                ZStack {
                    if forceOpaqueMaterials || reduceTransparency {
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

                    shape.strokeBorder(
                        polishedEdge,
                        lineWidth: edgeWidth
                    )
                }
            }
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
    }

    private var materialFill: Color {
        switch (role, colorScheme) {
        case (.hero, .light): SoftClubColor.elevatedSurface.opacity(0.90)
        case (.hero, .dark): SoftClubColor.elevatedSurface.opacity(0.86)
        case (.upcoming, .light): SoftClubColor.secondaryCanvas.opacity(0.30)
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
                .init(color: Color.clear, location: 0),
                .init(color: Color.white.opacity(colorScheme == .dark ? 0.04 : 0.07), location: 0.22),
                .init(
                    color: SoftClubColor.glassControlSurface.opacity(colorScheme == .dark ? 0.18 : 0.24),
                    location: 0.54
                ),
                .init(color: Color.white.opacity(colorScheme == .dark ? 0.06 : 0.10), location: 0.80),
                .init(color: Color.clear, location: 1),
            ],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }

    private var polishedEdge: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(colorScheme == .dark ? 0.22 : 0.66), location: 0),
                .init(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.20), location: 0.27),
                .init(color: Color.clear, location: 0.58),
                .init(color: SoftClubColor.mutedSecondary.opacity(colorScheme == .dark ? 0.13 : 0.18), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var edgeWidth: CGFloat {
        if colorSchemeContrast == .increased || forceIncreasedContrast {
            return 1
        }

        switch role {
        case .hero: return 0.65
        case .upcoming: return 0.38
        }
    }

    private var shadowColor: Color {
        switch (role, colorScheme) {
        case (.hero, .light): Color.black.opacity(0.055)
        case (.hero, .dark): Color.black.opacity(0.24)
        case (.upcoming, .light): Color.black.opacity(0.018)
        case (.upcoming, .dark): Color.black.opacity(0.10)
        @unknown default: Color.clear
        }
    }

    private var shadowRadius: CGFloat {
        switch role {
        case .hero: 16
        case .upcoming: 8
        }
    }

    private var shadowOffset: CGFloat {
        switch role {
        case .hero: 8
        case .upcoming: 3
        }
    }
}

// MARK: - Floating Navigation

private struct SorenDesignLockTabBar: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.designLockForceOpaqueMaterials) private var forceOpaqueMaterials
    @Environment(\.designLockForceIncreasedContrast) private var forceIncreasedContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedTab: DesignLockTab = .overview

    var body: some View {
        Group {
            if forceOpaqueMaterials || reduceTransparency || colorSchemeContrast == .increased || forceIncreasedContrast {
                tabItems
                    .padding(6)
                    .background(SoftClubColor.glassControlSurface, in: Capsule())
                    .overlay {
                        Capsule()
                            .strokeBorder(SoftClubColor.subtleBorder, lineWidth: 0.8)
                    }
            } else if #available(iOS 26, *) {
                GlassEffectContainer(spacing: 6) {
                    tabItems
                        .padding(6)
                        .glassEffect(
                            .regular,
                            in: .capsule
                        )
                }
            } else {
                tabItems
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 56 : 66)
    }

    private var tabItems: some View {
        HStack(spacing: 2) {
            ForEach(DesignLockTab.allCases) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: DesignLockTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.snappy(duration: 0.24)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 0 : 3) {
                Image(systemName: isSelected ? tab.activeIcon : tab.icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .frame(height: 19)

                if !dynamicTypeSize.isAccessibilitySize {
                    Text(verbatim: tab.title)
                        .font(.system(size: 9.5, weight: isSelected ? .medium : .regular))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(isSelected ? SoftClubColor.textPrimary : SoftClubColor.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .modifier(
            DesignLockSelectedTabGlassModifier(
                isSelected: isSelected,
                forceOpaque: forceOpaqueMaterials
                    || reduceTransparency
                    || colorSchemeContrast == .increased
                    || forceIncreasedContrast
            )
        )
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct DesignLockSelectedTabGlassModifier: ViewModifier {
    let isSelected: Bool
    let forceOpaque: Bool

    func body(content: Content) -> some View {
        if forceOpaque {
            content
                .background(
                    isSelected ? SoftClubColor.elevatedSurface.opacity(0.72) : Color.clear,
                    in: Capsule()
                )
        } else if #available(iOS 26, *) {
            if isSelected {
                content
                    .glassEffect(
                        .regular.interactive(),
                        in: .capsule
                    )
            } else {
                content
            }
        } else {
            content
                .background(
                    isSelected ? SoftClubColor.elevatedSurface.opacity(0.62) : Color.clear,
                    in: Capsule()
                )
        }
    }
}

private enum DesignLockTab: String, CaseIterable, Identifiable {
    case overview
    case subscriptions
    case calendar
    case analytics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Обзор"
        case .subscriptions: "Подписки"
        case .calendar: "Календарь"
        case .analytics: "Аналитика"
        }
    }

    var icon: String {
        switch self {
        case .overview: "house"
        case .subscriptions: "list.bullet"
        case .calendar: "calendar"
        case .analytics: "chart.bar"
        }
    }

    var activeIcon: String {
        switch self {
        case .overview: "house.fill"
        case .subscriptions: "list.bullet"
        case .calendar: "calendar"
        case .analytics: "chart.bar.fill"
        }
    }
}

// MARK: - Preview and Host

#Preview("Master Design Lock · Light") {
    DesignLockPrototypeView()
        .preferredColorScheme(.light)
}

#Preview("Master Design Lock · Dark") {
    DesignLockPrototypeView()
        .preferredColorScheme(.dark)
}

#Preview("Master Design Lock · Accessibility 3") {
    DesignLockPrototypeView()
        .preferredColorScheme(.light)
        .dynamicTypeSize(.accessibility3)
}

#Preview("Master Design Lock · Reduce Transparency") {
    DesignLockPrototypeView()
        .preferredColorScheme(.light)
        .environment(\.designLockForceOpaqueMaterials, true)
}

#if SOFT_CLUB_DESIGN_LOCK_HOST
@main
struct SoftClubDesignLockHostApp: App {
    private let arguments = ProcessInfo.processInfo.arguments

    var body: some Scene {
        WindowGroup {
            DesignLockHostContent(arguments: arguments)
        }
    }
}

private struct DesignLockHostContent: View {
    let arguments: [String]

    private var insight: OverviewInsightFixture {
        if arguments.contains("--design-lock-insight-attention") {
            .attention
        } else if arguments.contains("--design-lock-insight-dense-week") {
            .denseWeek
        } else {
            .annualScale
        }
    }

    private var colorScheme: ColorScheme {
        arguments.contains("--design-lock-dark") ? .dark : .light
    }

    private var forceOpaqueMaterials: Bool {
        arguments.contains("--design-lock-reduce-transparency")
    }

    private var forceIncreasedContrast: Bool {
        arguments.contains("--design-lock-increased-contrast")
    }

    var body: some View {
        if let subscriptionsVariant = SubscriptionsIAPrototypeVariant.requested(in: arguments) {
            SubscriptionsIAPrototypeHost(
                variant: subscriptionsVariant,
                colorScheme: SubscriptionsIAPrototypeVariant.colorScheme(in: arguments),
                dynamicTypeSize: SubscriptionsIAPrototypeVariant.dynamicTypeSize(in: arguments)
            )
        } else {
            Group {
                if arguments.contains("--design-lock-accessibility") {
                    prototype
                        .dynamicTypeSize(.accessibility3)
                } else {
                    prototype
                }
            }
        }
    }

    private var prototype: some View {
        DesignLockPrototypeView(insight: insight)
            .preferredColorScheme(colorScheme)
            .environment(\.designLockForceOpaqueMaterials, forceOpaqueMaterials)
            .environment(\.designLockForceIncreasedContrast, forceIncreasedContrast)
    }
}
#endif

private struct DesignLockForceOpaqueMaterialsKey: EnvironmentKey {
    static let defaultValue = false
}

private struct DesignLockForceIncreasedContrastKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var designLockForceOpaqueMaterials: Bool {
        get { self[DesignLockForceOpaqueMaterialsKey.self] }
        set { self[DesignLockForceOpaqueMaterialsKey.self] = newValue }
    }

    var designLockForceIncreasedContrast: Bool {
        get { self[DesignLockForceIncreasedContrastKey.self] }
        set { self[DesignLockForceIncreasedContrastKey.self] = newValue }
    }
}
#endif
