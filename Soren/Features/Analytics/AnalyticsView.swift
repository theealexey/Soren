import Charts
import SwiftUI

// MARK: - Analytics View

/// Insights & Analytics tab.
///
/// Presentation of normalized current obligations and the independent canonical forecast.
struct AnalyticsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.navigateToItem) private var navigateToItem
    @State private var viewModel: AnalyticsViewModel?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 32
    @ScaledMetric(relativeTo: .largeTitle) private var monthlySize = 40
    @ScaledMetric(relativeTo: .title2) private var annualSize = 22
    @ScaledMetric(relativeTo: .subheadline) private var heroCaptionSize = 14
    @ScaledMetric(relativeTo: .caption) private var metricCaptionSize = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Аналитика")
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)
            if let vm = viewModel {
                analyticsContent(vm)
            } else {
                LoadingStateView()
            }
        }
        .background(SoftClubColor.canvas)
        .task(id: container.refreshIdentity) {
            if viewModel == nil { viewModel = container.makeAnalyticsViewModel() }
            viewModel?.load(forceReload: true)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func analyticsContent(_ vm: AnalyticsViewModel) -> some View {
        Group {
            if vm.error != nil {
                ErrorStateView(message: "Не удалось загрузить данные") {
                    vm.load(forceReload: true)
                }
            } else if !vm.isLoaded {
                LoadingStateView()
            } else if vm.screenState.isEmpty {
                emptyState
            } else {
                scrollContent(vm)
            }
        }
        .task(id: vm.aggregationRevision) {
            let revision = vm.aggregationRevision
            await vm.refreshCurrencyAggregation(revision: revision)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "Нет данных"),
            systemImage: "chart.bar",
            description: Text(String(localized: "Добавьте подписки, чтобы увидеть аналитику"))
        )
    }

    // MARK: - Scroll Content

    private func scrollContent(_ vm: AnalyticsViewModel) -> some View {
        let state = vm.screenState
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                overviewSection(state)

                if state.normalizationError != nil {
                    normalizedSectionUnavailable("Топ подписки")
                }

                if !state.topItems.isEmpty {
                    topItemsSection(state)
                }

                if state.normalizationError != nil {
                    normalizedSectionUnavailable("По категориям")
                } else if !state.categoryBreakdown.isEmpty {
                    categorySection(state)
                }

                if state.forecastMonths.count == 6 {
                    forecastSection(state)
                }

                if !state.annualItems.isEmpty {
                    annualSection(state)
                }

                if !state.unusedItems.isEmpty {
                    unusedSection(state)
                }
            }
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 1. Overview

    private func overviewSection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(inset: 20) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("analytics.recurringCost")
                    .font(.system(size: heroCaptionSize, weight: .medium))
                    .foregroundStyle(SoftClubColor.textSecondary)

                overviewCards(state)

                aggregationStatus(state.monthlyAggregation)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    metricChip(
                        icon: "repeat",
                        text: state.includedCountLabel()
                    )

                    if state.summary.activeTrialCount > 0 {
                        metricChip(
                            icon: "clock",
                            text: RecurringItemFormatter.trialCountLabel(count: state.summary.activeTrialCount)
                        )
                    }

                    if !state.unusedItems.isEmpty {
                        metricChip(
                            icon: "exclamationmark.circle",
                            value: "\(state.unusedItems.count)",
                            label: String(localized: "неиспользуемых"),
                            isWarning: true
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 152)
        .padding(.horizontal, 20)
    }

    private func overviewCards(_ state: AnalyticsScreenState) -> some View {
        ViewThatFits(in: .horizontal) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .bottom, spacing: 20) {
                    heroMetric(
                        state.monthlyAggregation, title: "В месяц", size: monthlySize,
                        failed: state.normalizationError != nil
                    )
                    .layoutPriority(1)
                    .fixedSize(horizontal: true, vertical: true)
                    Spacer(minLength: 0)
                    heroMetric(
                        state.annualAggregation, title: "В год", size: annualSize,
                        failed: state.normalizationError != nil
                    )
                    .fixedSize(horizontal: true, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                heroMetric(
                    state.monthlyAggregation, title: "В месяц", size: monthlySize,
                    failed: state.normalizationError != nil)
                heroMetric(
                    state.annualAggregation, title: "В год", size: annualSize,
                    failed: state.normalizationError != nil)
            }
        }
    }

    private func heroMetric(
        _ aggregation: RecurringSpendAggregationResult?, title: LocalizedStringKey,
        size: CGFloat, failed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: metricCaptionSize)).foregroundStyle(
                SoftClubColor.textSecondary)
            if let total = aggregation?.total {
                Text(
                    NormalizedMoneyFormatter.string(amount: total.amount, currencyCode: total.currencyCode)
                )
                .font(.system(size: size)).monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                if case .partial = aggregation {
                    Text("Частично").font(.caption).foregroundStyle(SoftClubColor.textSecondary)
                }
            } else {
                Text(verbatim: failed ? String(localized: "normalization.unavailable") : "—")
                    .font(.body).foregroundStyle(SoftClubColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func normalizedSectionUnavailable(_ title: String) -> some View {
        AnalyticsSurface(title: title) {
            Text(String(localized: "normalization.unavailable"))
                .font(.footnote)
                .foregroundStyle(SoftClubColor.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
    }

    @ViewBuilder
    private func aggregationStatus(_ aggregation: RecurringSpendAggregationResult?) -> some View {
        if let aggregation {
            switch aggregation {
            case .complete(_, let metadata):
                staleRateLabel(metadata)

            case .partial(_, let missingCodes, let metadata):
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(String(localized: "Частично"))
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.warning)
                    Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.warning)
                    staleRateLabel(metadata)
                }

            case .unavailable(_, let missingCodes, _, let metadata):
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(String(localized: "Курсы валют недоступны"))
                        .font(.footnote)
                        .foregroundStyle(SoftClubColor.textSecondary)
                    if !missingCodes.isEmpty {
                        Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                            .font(.footnote)
                            .foregroundStyle(SoftClubColor.textSecondary)
                    }
                    staleRateLabel(metadata)
                }
            }
        }
    }

    @ViewBuilder
    private func staleRateLabel(_ metadata: SpendAggregationRateMetadata?) -> some View {
        if let metadata, case .stale = metadata.freshness {
            Text(String(localized: "По сохранённому курсу"))
                .font(.footnote)
                .foregroundStyle(ColorTokens.warning)
        }
    }

    /// Two-part chip: bold numeric value + regular noun label (e.g. "5 активных").
    private func metricChip(
        icon: String,
        value: String,
        label: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
            Text(verbatim: value)
                .font(.system(.caption, weight: .medium))
            Text(verbatim: label)
                .font(.caption)
        }
        .foregroundStyle(isWarning ? ColorTokens.warning : ColorTokens.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            (isWarning ? ColorTokens.warning : ColorTokens.textSecondary).opacity(0.1),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }

    /// Single-text chip: icon + one pre-composed localized string (e.g. "3 пробных").
    /// Use when the localized string already encodes count and noun together via CLDR
    /// plural rules, so no separate label field is needed.
    private func metricChip(
        icon: String,
        text: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
            Text(verbatim: text)
                .font(.system(.caption, weight: .medium))
        }
        .foregroundStyle(isWarning ? ColorTokens.warning : ColorTokens.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            (isWarning ? ColorTokens.warning : ColorTokens.textSecondary).opacity(0.1),
            in: Capsule()
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - 2. Spending Forecast

    private func forecastSection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(title: String(localized: "Прогноз на 6 месяцев")) {
            VStack(alignment: .leading, spacing: 12) {
                Text("overview.monthlyPlan.scheduled")
                    .font(.caption).foregroundStyle(SoftClubColor.textSecondary)
                if state.monthlyProjections.isEmpty {
                    if state.forecastMonths.contains(where: {
                        $0.schedule.monetaryCompleteness == .unavailable
                    }) {
                        Text(String(localized: "Прогноз недоступен"))
                            .font(.footnote)
                            .foregroundStyle(SoftClubColor.textSecondary)
                    }
                    if let incomplete = state.forecastMonths.first(where: { !$0.aggregation.isComplete }) {
                        aggregationStatus(incomplete.aggregation)
                    }
                } else if dynamicTypeSize.isAccessibilitySize {
                    ForEach(state.monthlyProjections) { projection in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(projection.shortLabel).font(.headline)
                            Text(
                                AnalyticsPresentation.forecastAmount(
                                    projection.total, currency: state.defaultCurrency)
                            )
                            .font(.body).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                } else {
                    Chart(state.monthlyProjections) { proj in
                        BarMark(
                            x: .value(String(localized: "Месяц"), proj.shortLabel),
                            y: .value(String(localized: "Сумма"), proj.doubleTotal)
                        )
                        .foregroundStyle(ColorTokens.accent.gradient)
                        .cornerRadius(6)
                        .annotation(position: .top, alignment: .center) {
                            if proj.doubleTotal > 0 {
                                Text(
                                    AnalyticsPresentation.forecastAmount(proj.total, currency: state.defaultCurrency)
                                )
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SoftClubColor.textSecondary)
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                    .frame(height: 168)
                    .padding(.top, Spacing.xs)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Прогноз на 6 месяцев"))
                    .accessibilityValue(
                        state.monthlyProjections.map {
                            $0.shortLabel + ": "
                                + AnalyticsPresentation.forecastAmount($0.total, currency: state.defaultCurrency)
                        }.joined(separator: "; "))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 3. Category Breakdown

    private func categorySection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(title: String(localized: "По категориям")) {
            VStack(spacing: Spacing.sm) {
                ForEach(state.categoryBreakdown) { spend in
                    categoryRow(spend, currency: state.defaultCurrency)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func categoryRow(
        _ spend: CategorySpend,
        currency: String
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    Text(spend.category.displayName).font(.body)
                    categoryAmount(spend, currency: currency)
                    categoryTrack(spend)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: spend.category.systemIconName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SoftClubColor.textSecondary)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    Text(spend.category.displayName)
                        .font(.body)
                        .frame(minWidth: 70, alignment: .leading)
                    categoryTrack(spend)
                    categoryAmount(spend, currency: currency)
                        .frame(minWidth: 70, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(SoftClubColor.textPrimary)
        .accessibilityElement(children: .combine)
    }

    private func categoryAmount(_ spend: CategorySpend, currency: String) -> some View {
        Text(NormalizedMoneyFormatter.string(amount: spend.monthlyTotal, currencyCode: currency))
            .font(.subheadline).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    private func categoryTrack(_ spend: CategorySpend) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(SoftClubColor.icyPrimary.opacity(0.12))
                RoundedRectangle(cornerRadius: 3)
                    .fill(ColorTokens.accent.gradient)
                    .frame(width: proxy.size.width * spend.proportion)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    // MARK: - 4. Top Subscriptions

    private func topItemsSection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(title: String(localized: "Топ подписки")) {
            VStack(spacing: 0) {
                ForEach(Array(state.topItems.enumerated()), id: \.element.id) { idx, row in
                    Button {
                        navigateToItem(row.navigationItem)
                    } label: {
                        AnalyticsItemRow(
                            title: row.title,
                            subtitle: row.subtitle,
                            amount: row.monthlyAmount,
                            currency: row.currency,
                            cycle: .monthly,
                            providerTemplate: row.providerTemplate,
                            category: row.category,
                            normalized: true
                        )
                    }
                    .buttonStyle(.plain)

                    if idx < state.topItems.count - 1 {
                        Divider().padding(.leading, SorenListRow.dividerInset)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 5. Annual Payments

    private func annualSection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(title: String(localized: "Годовые платежи")) {
            VStack(spacing: 0) {
                ForEach(Array(state.annualItems.enumerated()), id: \.element.id) { idx, row in
                    let item = row.item
                    Button {
                        navigateToItem(item)
                    } label: {
                        AnalyticsItemRow(
                            title: item.title,
                            subtitle: row.subtitle,
                            amount: item.amount,
                            currency: item.currencyCode,
                            cycle: .yearly,
                            providerTemplate: item.providerTemplate,
                            category: item.category
                        )
                    }
                    .buttonStyle(.plain)

                    if idx < state.annualItems.count - 1 {
                        Divider().padding(.leading, SorenListRow.dividerInset)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 6. Unused / Waste

    private func unusedSection(_ state: AnalyticsScreenState) -> some View {
        AnalyticsSurface(title: String(localized: "Не используются")) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    if state.normalizationError != nil {
                        Text(String(localized: "normalization.unavailable"))
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    } else if let unusedMonthlyCost = state.unusedMonthlyCost, unusedMonthlyCost > 0 {
                        Text(
                            String(
                                localized:
                                    "−\(wasteString(unusedMonthlyCost, currency: state.defaultCurrency)) \(state.defaultCurrency)/мес"
                            )
                        )
                        .font(Typography.captionMedium)
                        .foregroundStyle(ColorTokens.warning)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxxs)
                        .background(ColorTokens.warning.opacity(0.1), in: Capsule())
                    }
                }
                VStack(spacing: 0) {
                    ForEach(Array(state.unusedItems.enumerated()), id: \.element.id) { idx, item in
                        Button {
                            navigateToItem(item)
                        } label: {
                            AnalyticsItemRow(
                                title: item.title,
                                subtitle: String(localized: "Не используется"),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                                providerTemplate: item.providerTemplate,
                                category: item.category
                            )
                        }
                        .buttonStyle(.plain)

                        if idx < state.unusedItems.count - 1 {
                            Divider().padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func wasteString(_ amount: Decimal, currency: String) -> String {
        NormalizedMoneyFormatter.string(amount: amount, currencyCode: currency, style: .decimal)
    }
}

// MARK: - Analytics-local surfaces and rows

private struct AnalyticsSurface<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .headline) private var headingSize = 18
    var title: String? = nil
    var inset: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.system(size: headingSize, weight: .semibold))
                    .foregroundStyle(SoftClubColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(inset)
        .background(SoftClubColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    contrast == .increased ? SoftClubColor.textSecondary : SoftClubColor.subtleBorder,
                    lineWidth: contrast == .increased ? 1 : 0.5)
        }
    }
}

private struct AnalyticsItemRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textSize = 16
    let title: String
    let subtitle: String?
    let amount: Decimal
    let currency: String
    let cycle: AmountLabel.CycleLabel?
    let providerTemplate: ProviderTemplate?
    let category: ItemCategory
    var normalized = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon.accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 12) {
                        identity
                            .fixedSize(horizontal: true, vertical: true)
                        Spacer(minLength: 0)
                        money
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    identity
                    money
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: textSize, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle).font(.caption)
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var money: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedAmount).font(.system(size: textSize, weight: .medium))
                .monospacedDigit().foregroundStyle(SoftClubColor.textPrimary)
            if let cycle {
                Text(cycle.label).font(.caption).foregroundStyle(SoftClubColor.textSecondary)
                    .accessibilityLabel(cycle.accessibilityText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var formattedAmount: String {
        if normalized {
            return NormalizedMoneyFormatter.string(amount: amount, currencyCode: currency)
        }
        // Match existing original-amount formatting without changing shared components.
        let formatter = NumberFormatter()
        formatter.locale = PresentationLocale.current
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currency)"
    }

    @ViewBuilder private var icon: some View {
        if let providerTemplate {
            ProviderIcon(provider: providerTemplate, size: .medium)
        } else {
            Image(systemName: category.systemIconName)
                .font(.body).foregroundStyle(SoftClubColor.textSecondary)
                .frame(width: 40, height: 40)
                .background(SoftClubColor.elevatedSurface, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
