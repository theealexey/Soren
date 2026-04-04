import SwiftUI

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
    @State private var viewModel: AnalyticsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    analyticsContent(vm)
                } else {
                    LoadingStateView()
                }
            }
            .background(ColorTokens.background)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task {
                guard viewModel == nil else { return }
                let vm = AnalyticsViewModel(
                    repositories: container.repositories,
                    preferences: container.preferences,
                    exchangeRateProvider: container.exchangeRateProvider
                )
                viewModel = vm
                await vm.load()
            }
            .onChange(of: container.itemsVersion) { _, _ in
                viewModel?.loadLocalData(forceReload: true)
            }
            .navigationDestination(for: RecurringItem.self) { item in
                ItemDetailsView(
                    viewModel: ItemDetailsViewModel(
                        item: item,
                        repositories: container.repositories
                    )
                )
            }
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
        } else if vm.summary == .empty {
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                overviewSection(vm)

                if !vm.categoryBreakdown.isEmpty {
                    categorySection(vm)
                }

                if !vm.topItems.isEmpty {
                    topItemsSection(vm)
                }

                if !vm.annualItems.isEmpty {
                    annualSection(vm)
                }

                if !vm.unusedItems.isEmpty {
                    unusedSection(vm)
                }
            }
            .padding(.vertical, Spacing.md)
        }
    }

    // MARK: - 1. Overview

    private func overviewSection(_ vm: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Обзор"))
                .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: vm.summary.monthlyTotal,
                        currency: vm.defaultCurrency
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: vm.summary.yearlyProjection,
                        currency: vm.defaultCurrency
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)

            HStack(spacing: Spacing.xs) {
                metricChip(
                    icon: "repeat",
                    value: "\(vm.summary.activeItemCount)",
                    label: String(localized: "активных")
                )

                if vm.summary.activeTrialCount > 0 {
                    metricChip(
                        icon: "clock",
                        value: "\(vm.summary.activeTrialCount)",
                        label: String(localized: "пробных")
                    )
                }

                if !vm.unusedItems.isEmpty {
                    metricChip(
                        icon: "exclamationmark.circle",
                        value: "\(vm.unusedItems.count)",
                        label: String(localized: "неиспользуемых"),
                        isWarning: true
                    )
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

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

    // MARK: - 2. Category Breakdown

    private func categorySection(_ vm: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "По категориям"))
                .padding(.horizontal, Spacing.lg)

            stackedBar(vm.categoryBreakdown)
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: Spacing.sm) {
                    let maxProportion = vm.categoryBreakdown.first?.proportion ?? 1
                    ForEach(vm.categoryBreakdown) { spend in
                        categoryRow(spend, maxProportion: maxProportion, currency: vm.defaultCurrency)
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

    // MARK: - 3. Top Subscriptions

    private func topItemsSection(_ vm: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Топ подписки"))
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.topItems.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink(value: item) {
                            SorenListRow(
                                title: item.title,
                                subtitle: item.providerName == item.title ? nil : item.providerName,
                                amount: vm.monthlyAmount(item),
                                currency: vm.defaultCurrency,
                                cycle: .monthly,
                                providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                                category: item.category
                            )
                        }
                        .buttonStyle(.plain)

                        if idx < vm.topItems.count - 1 {
                            Divider().padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    // MARK: - 4. Annual Payments

    private func annualSection(_ vm: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Годовые платежи"))
                .padding(.horizontal, Spacing.lg)

            PremiumCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.annualItems.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink(value: item) {
                            SorenListRow(
                                title: item.title,
                                subtitle: nextAnnualLabel(for: item),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: .yearly,
                                providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                                category: item.category
                            )
                        }
                        .buttonStyle(.plain)

                        if idx < vm.annualItems.count - 1 {
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

    // MARK: - 5. Unused / Waste

    private func unusedSection(_ vm: AnalyticsViewModel) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                SectionHeader(String(localized: "Не используются"))
                Spacer()
                if vm.unusedMonthlyCost > 0 {
                    Text(String(localized: "−\(wasteString(vm.unusedMonthlyCost)) \(vm.defaultCurrency)/мес"))
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
                    ForEach(Array(vm.unusedItems.enumerated()), id: \.element.id) { idx, item in
                        NavigationLink(value: item) {
                            SorenListRow(
                                title: item.title,
                                subtitle: String(localized: "Не используется"),
                                amount: item.amount,
                                currency: item.currencyCode,
                                cycle: item.billingCycle.cycleLabel,
                                providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                                category: item.category,
                                badge: .paused
                            )
                        }
                        .buttonStyle(.plain)

                        if idx < vm.unusedItems.count - 1 {
                            Divider().padding(.leading, SorenListRow.dividerInset)
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func wasteString(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? amount.description
    }
}

// MARK: - BillingCycle+CycleLabel

private extension BillingCycle {
    var cycleLabel: AmountLabel.CycleLabel {
        switch self {
        case .weekly:            .weekly
        case .monthly:           .monthly
        case .quarterly:         .custom(String(localized: "квар"))
        case .semiannual:        .custom(String(localized: "пол"))
        case .annual:            .yearly
        case .custom(let days):  .custom("\(days)д")
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
