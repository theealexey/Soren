import SwiftUI
import Charts

// MARK: - Analytics View

/// Insights & Analytics tab.
///
/// Sections:
/// 1. Overview — monthly/yearly totals
/// 2. Spending by category — stacked bar + category list
/// 3. Top subscriptions — top 5 by monthly cost
/// 4. Annual payments — big one-time lump sums to plan for
/// 5. Unused — waste candidates with total savings potential
struct AnalyticsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.navigateToItem) private var navigateToItem
    @State private var viewModel: AnalyticsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                analyticsContent(vm)
            } else {
                LoadingStateView()
            }
        }
        .background(ColorTokens.background)
        .task {
            guard viewModel == nil else { return }
            let vm = container.makeAnalyticsViewModel()
            viewModel = vm
            await vm.load()
        }
        .onChange(of: container.itemsVersion) { _, _ in
            viewModel?.loadLocalData(forceReload: true)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func analyticsContent(_ vm: AnalyticsViewModel) -> some View {
        if vm.error != nil {
            ErrorStateView(message: "Не удалось загрузить данные") {
                Task { await vm.load(forceReload: true) }
            }
        } else if !vm.isLoaded {
            LoadingStateView()
        } else if vm.screenState.isEmpty {
            emptyState
        } else {
            scrollContent(vm)
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

                if state.monthlyProjections.count > 1 {
                    forecastSection(state)
                }

                if !state.categoryBreakdown.isEmpty {
                    categorySection(state)
                }

                if !state.topItems.isEmpty {
                    topItemsSection(state)
                }

                if !state.annualItems.isEmpty {
                    annualSection(state)
                }

                if !state.unusedItems.isEmpty {
                    unusedSection(state)
                }
            }
            .padding(.vertical, Spacing.md)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - 1. Overview

    private func overviewSection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Обзор"))
                .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: state.summary.monthlyTotal,
                        currency: state.defaultCurrency
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: state.summary.yearlyProjection,
                        currency: state.defaultCurrency
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.xs) {
                metricChip(
                    icon: "repeat",
                    value: "\(state.summary.activeItemCount)",
                    label: String(localized: "активных")
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
            .padding(.horizontal, Spacing.lg)
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
            Text(verbatim: value)
                .font(Typography.captionMedium)
            Text(verbatim: label)
                .font(Typography.caption)
        }
        .foregroundStyle(isWarning ? ColorTokens.warning : ColorTokens.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            (isWarning ? ColorTokens.warning : ColorTokens.textSecondary).opacity(0.1),
            in: Capsule()
        )
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
            Text(verbatim: text)
                .font(Typography.captionMedium)
        }
        .foregroundStyle(isWarning ? ColorTokens.warning : ColorTokens.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            (isWarning ? ColorTokens.warning : ColorTokens.textSecondary).opacity(0.1),
            in: Capsule()
        )
    }

    // MARK: - 2. Spending Forecast

    private func forecastSection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Прогноз на 6 месяцев"))
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                Chart(state.monthlyProjections) { proj in
                    BarMark(
                        x: .value("Месяц", proj.shortLabel),
                        y: .value("Сумма", proj.doubleTotal)
                    )
                    .foregroundStyle(ColorTokens.accent.gradient)
                    .cornerRadius(6)
                    .annotation(position: .top, alignment: .center) {
                        if proj.doubleTotal > 0 {
                            Text(compactAmount(proj.total, currency: state.defaultCurrency))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(ColorTokens.textSecondary)
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
                .frame(height: 160)
                .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func compactAmount(_ amount: Decimal, currency: String) -> String {
        let n = NSDecimalNumber(decimal: amount).doubleValue
        Self.annotationFormatter.currencyCode = currency
        let symbol = Self.annotationFormatter.currencySymbol ?? currency
        if n >= 1_000_000 {
            return String(format: "%.1fM %@", n / 1_000_000, symbol)
        } else if n >= 1_000 {
            return String(format: "%.0fK %@", n / 1_000, symbol)
        }
        return String(format: "%.0f %@", n, symbol)
    }

    private static let annotationFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    // MARK: - 3. Category Breakdown

    private func categorySection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "По категориям"))
                .padding(.horizontal, Spacing.lg)

            stackedBar(state.categoryBreakdown)
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: Spacing.sm) {
                    let maxProportion = state.categoryBreakdown.first?.proportion ?? 1
                    ForEach(state.categoryBreakdown) { spend in
                        categoryRow(spend, maxProportion: maxProportion, currency: state.defaultCurrency)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func stackedBar(_ breakdown: [CategorySpend]) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(breakdown.prefix(8)) { spend in
                    spend.category.color
                        .frame(width: max(2, proxy.size.width * spend.proportion - 2))
                }
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func categoryRow(
        _ spend: CategorySpend,
        maxProportion: Double,
        currency: String
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: spend.category.systemIconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(spend.category.color)
                .frame(width: 20)

            Text(spend.category.displayName)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)
                .frame(minWidth: 70, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(spend.category.color.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(spend.category.color)
                        .frame(width: max(4, proxy.size.width * (spend.proportion / maxProportion)))
                }
            }
            .frame(height: 6)

            AmountLabel(spend.monthlyTotal, currency: currency, size: .small)
                .frame(minWidth: 70, alignment: .trailing)
        }
    }

    // MARK: - 4. Top Subscriptions

    private func topItemsSection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Топ подписки"))
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(state.topItems.enumerated()), id: \.element.id) { idx, row in
                        Button { navigateToItem(row.navigationItem) } label: {
                            SorenListRow(
                                title: row.title,
                                subtitle: row.subtitle,
                                amount: row.monthlyAmount,
                                currency: row.currency,
                                cycle: .monthly,
                                providerTemplate: row.providerTemplate,
                                category: row.category
                            )
                        }
                        .buttonStyle(.plain)

                        if idx < state.topItems.count - 1 {
                            Divider().padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - 5. Annual Payments

    private func annualSection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Годовые платежи"))
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(state.annualItems.enumerated()), id: \.element.id) { idx, item in
                        Button { navigateToItem(item) } label: {
                            SorenListRow(
                                title: item.title,
                                subtitle: nextAnnualLabel(for: item),
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
            .padding(.horizontal, Spacing.lg)
        }
    }

    private static let chargeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    private func nextAnnualLabel(for item: RecurringItem) -> String {
        let days = item.daysUntilNextCharge
        let dateStr = Self.chargeDateFormatter.string(from: item.nextChargeDate)
        if days < 0   { return String(localized: "Просрочено — \(dateStr)") }
        if days == 0  { return String(localized: "Сегодня") }
        if days <= 30 { return String(localized: "Через \(days) дн. — \(dateStr)") }
        return String(localized: "\(dateStr)")
    }

    // MARK: - 6. Unused / Waste

    private func unusedSection(_ state: AnalyticsScreenState) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionHeader(String(localized: "Не используются"))
                Spacer()
                if state.unusedMonthlyCost > 0 {
                    Text(String(localized: "−\(wasteString(state.unusedMonthlyCost)) \(state.defaultCurrency)/мес"))
                        .font(Typography.captionMedium)
                        .foregroundStyle(ColorTokens.warning)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxxs)
                        .background(ColorTokens.warning.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(state.unusedItems.enumerated()), id: \.element.id) { idx, item in
                        Button { navigateToItem(item) } label: {
                            SorenListRow(
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
            .padding(.horizontal, Spacing.lg)
        }
    }

    private static let wasteFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    private func wasteString(_ amount: Decimal) -> String {
        Self.wasteFormatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
