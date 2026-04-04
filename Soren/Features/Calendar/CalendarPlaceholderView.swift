import SwiftUI

// MARK: - Calendar View

/// Full monthly calendar showing subscription charge dates.
///
/// Layout: month navigation header → weekday labels →
/// 7-column day grid with charge indicators → selected-day charge list.
struct CalendarView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: CalendarViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    calendarContent(vm)
                } else {
                    LoadingStateView()
                }
            }
            .background(ColorTokens.background)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .task {
                guard viewModel == nil else { return }
                let vm = CalendarViewModel(
                    repository: container.repositories.recurringItems,
                    preferences: container.preferences
                )
                viewModel = vm
                vm.load()
            }
            .onChange(of: container.itemsVersion) { _, _ in
                viewModel?.load(forceReload: true)
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

    // MARK: - Calendar Content

    @ViewBuilder
    private func calendarContent(_ vm: CalendarViewModel) -> some View {
        if let error = vm.error {
            ErrorStateView(message: "Не удалось загрузить данные") {
                vm.load(forceReload: true)
            }
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    monthNavHeader(vm)
                    weekdayHeader
                    calendarGrid(vm)
                    selectedDaySection(vm)
                }
            }
        }
    }

    // MARK: - Month Navigation

    private func monthNavHeader(_ vm: CalendarViewModel) -> some View {
        HStack {
            Button {
                HapticEngine.selection()
                vm.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.accent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(vm.monthTitle)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
                .contentTransition(.numericText())
                .animation(MotionTokens.snappy, value: vm.monthTitle)

            Spacer()

            Button {
                HapticEngine.selection()
                vm.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.accent)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(Typography.captionMedium)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    /// Mon-first short weekday labels for Russian locale.
    private static let weekdayLabels: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        var symbols = cal.veryShortStandaloneWeekdaySymbols
        // Default order is Sun-first: [Вс, Пн, Вт, Ср, Чт, Пт, Сб]
        // Rotate by moving Sunday to the end → [Пн, Вт, Ср, Чт, Пт, Сб, Вс]
        if symbols.count == 7 {
            let sunday = symbols.removeFirst()
            symbols.append(sunday)
        }
        return symbols
    }()

    // MARK: - Calendar Grid

    private func calendarGrid(_ vm: CalendarViewModel) -> some View {
        let rows = vm.daysInGrid.chunked(into: 7)
        return VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(rows[rowIndex]) { day in
                        dayCell(day, vm: vm)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .animation(MotionTokens.snappy, value: vm.displayedMonth)
    }

    // MARK: - Day Cell

    private func dayCell(_ day: CalendarDay, vm: CalendarViewModel) -> some View {
        let isSelected = Calendar.current.isDate(day.date, inSameDayAs: vm.selectedDate)
        let charges = vm.chargesByDate[day.date] ?? []

        return Button {
            withAnimation(MotionTokens.snappy) { vm.selectDate(day.date) }
            if !charges.isEmpty { HapticEngine.selection() }
        } label: {
            VStack(spacing: Spacing.xxs) {
                dayNumber(day: day, isSelected: isSelected)
                chargeDots(charges: charges, isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    private func dayNumber(day: CalendarDay, isSelected: Bool) -> some View {
        Text("\(Calendar.current.component(.day, from: day.date))")
            .font(day.isToday ? Typography.bodyMedium : Typography.body)
            .foregroundStyle(
                isSelected    ? .white :
                day.isToday   ? ColorTokens.accent :
                day.isCurrentMonth ? ColorTokens.textPrimary :
                ColorTokens.textTertiary
            )
            .frame(width: 32, height: 32)
            .background {
                if isSelected {
                    Circle().fill(ColorTokens.accent)
                } else if day.isToday {
                    Circle().strokeBorder(ColorTokens.accent, lineWidth: 1.5)
                }
            }
    }

    @ViewBuilder
    private func chargeDots(charges: [RecurringItem], isSelected: Bool) -> some View {
        if charges.isEmpty {
            Color.clear.frame(height: 6)
        } else {
            HStack(spacing: 3) {
                ForEach(0..<min(charges.count, 3), id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? Color.white : ColorTokens.accent)
                        .frame(width: 4, height: 4)
                }
                if charges.count > 3 {
                    Text("+\(charges.count - 3)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : ColorTokens.accent)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Selected Day Section

    @ViewBuilder
    private func selectedDaySection(_ vm: CalendarViewModel) -> some View {
        let charges = vm.selectedDayCharges

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Divider()
                .padding(.top, Spacing.sm)

            SectionHeader(Self.dayTitle(for: vm.selectedDate))
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)

            if charges.isEmpty {
                Text(String(localized: "Нет платежей"))
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Spacing.xl)
            } else {
                PremiumCard {
                    VStack(spacing: 0) {
                        ForEach(Array(charges.enumerated()), id: \.element.id) { idx, item in
                            NavigationLink(value: item) {
                                SorenListRow(
                                    title: item.title,
                                    subtitle: item.providerName == item.title ? nil : item.providerName,
                                    amount: item.amount,
                                    currency: item.currencyCode,
                                    cycle: item.billingCycle.cycleLabel,
                                    providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
                                    category: item.category
                                )
                            }
                            .buttonStyle(.plain)

                            if idx < charges.count - 1 {
                                Divider()
                                    .padding(.leading, SorenListRow.dividerInset)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            if vm.monthlyTotal > 0 {
                monthlyTotalFooter(total: vm.monthlyTotal, currency: vm.defaultCurrency)
            }
        }
        .padding(.bottom, Spacing.xxxl)
        .animation(MotionTokens.snappy, value: vm.selectedDate)
    }

    private func monthlyTotalFooter(total: Decimal, currency: String) -> some View {
        HStack {
            Text(String(localized: "Итого за месяц"))
                .font(Typography.captionMedium)
                .foregroundStyle(ColorTokens.textSecondary)
            Spacer()
            AmountLabel(total, currency: currency, size: .medium)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private static func dayTitle(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Сегодня")
        }
        if Calendar.current.isDateInTomorrow(date) {
            return String(localized: "Завтра")
        }
        return Self.dayFormatter.string(from: date).capitalized
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()
}

// MARK: - Array+Chunked

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - BillingCycle+CycleLabel

private extension BillingCycle {
    var cycleLabel: AmountLabel.CycleLabel {
        switch self {
        case .weekly:               .weekly
        case .monthly:              .monthly
        case .quarterly:            .custom(String(localized: "квар"))
        case .semiannual:           .custom(String(localized: "пол"))
        case .annual:               .yearly
        case .custom(let days):     .custom("\(days)д")
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
