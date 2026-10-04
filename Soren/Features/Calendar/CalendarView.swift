import SwiftUI

// MARK: - Calendar View

/// Full monthly calendar showing subscription charge dates.
///
/// Layout: month navigation header → weekday labels →
/// 7-column day grid with charge indicators → selected-day charge list.
struct CalendarView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.navigateToItem) private var navigateToItem
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CalendarViewModel?

    /// Maximum width of the calendar content column.
    /// Keeps day cells at a comfortable size on iPad and Mac — matching the
    /// ~55-65 pt per cell cadence that feels natural on iPhone.
    /// On any iPhone (max 430 pt wide) this cap is never reached.
    private let calendarContentMaxWidth: CGFloat = 460

    var body: some View {
        Group {
            if let vm = viewModel {
                calendarContent(vm)
            } else {
                LoadingStateView()
            }
        }
        .background(ColorTokens.background)
        .task {
            guard viewModel == nil else { return }
            let vm = container.makeCalendarViewModel()
            viewModel = vm
            vm.load()
        }
        .onChange(of: container.itemsVersion) { _, _ in
            viewModel?.load(forceReload: true)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, viewModel?.isLoaded == true else { return }
            viewModel?.load(forceReload: true)
        }
    }

    // MARK: - Calendar Content

    @ViewBuilder
    private func calendarContent(_ vm: CalendarViewModel) -> some View {
        Group {
            if vm.error != nil {
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
                    .frame(maxWidth: calendarContentMaxWidth)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .task(id: vm.aggregationRevision) {
            let revision = vm.aggregationRevision
            await vm.refreshCurrencyAggregation(revision: revision)
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
            .accessibilityLabel(Text(String(localized: "Предыдущий месяц")))
            .disabled(!vm.canNavigatePreviousMonth)

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
            .accessibilityLabel(Text(String(localized: "Следующий месяц")))
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
        .accessibilityHidden(true)
    }

    /// Mon-first short weekday labels derived from the app's presentation locale.
    /// Rotation uses `firstWeekday` so the logic matches `buildGrid()` in the ViewModel.
    private static let weekdayLabels: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = PresentationLocale.current
        cal.firstWeekday = 2
        var symbols = cal.veryShortStandaloneWeekdaySymbols
        // API returns Sun-first: [Вс, Пн, Вт, Ср, Чт, Пт, Сб]
        // Rotate by (firstWeekday - 1) to get Mon-first: [Пн, Вт, Ср, Чт, Пт, Сб, Вс]
        let rotation = cal.firstWeekday - 1
        guard rotation > 0, symbols.count > rotation else { return symbols }
        symbols = Array(symbols[rotation...]) + Array(symbols[..<rotation])
        return symbols
    }()

    // MARK: - Calendar Grid

    private func calendarGrid(_ vm: CalendarViewModel) -> some View {
        let rows = vm.daysInGrid.chunked(into: 7)
        return VStack(spacing: 0) {
            // Use first day's date as stable row identifier so SwiftUI can animate
            // correctly when row count changes between months (4 vs 5 vs 6 rows).
            ForEach(rows, id: \.first?.date) { row in
                HStack(spacing: 0) {
                    ForEach(row) { day in
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
        let isSelected = CalendarViewModel.cal.isDate(day.date, inSameDayAs: vm.selectedDate)
        let charges = (vm.occurrencesByDate[day.date] ?? []).map(\.item)
        let dayNumber = CalendarViewModel.cal.component(.day, from: day.date)

        return Button {
            withAnimation(MotionTokens.snappy) { vm.selectDate(day.date) }
            if !charges.isEmpty { HapticEngine.selection() }
        } label: {
            VStack(spacing: Spacing.xxs) {
                dayNumberView(number: dayNumber, day: day, isSelected: isSelected)
                chargeDots(charges: charges, isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDayLabel(day: day, charges: charges))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func dayNumberView(number: Int, day: CalendarDay, isSelected: Bool) -> some View {
        Text("\(number)")
            .font(day.isToday ? Typography.bodyMedium : Typography.body)
            .foregroundStyle(
                isSelected         ? .white :
                day.isToday        ? ColorTokens.accent :
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
                // Use stable item IDs so SwiftUI animates dot add/remove correctly.
                ForEach(Array(charges.prefix(3).enumerated()), id: \.offset) { _ in
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

    private func accessibilityDayLabel(day: CalendarDay, charges: [RecurringItem]) -> Text {
        let dayStr = Self.accessibilityDayFormatter.string(from: day.date)
        if charges.isEmpty { return Text(verbatim: dayStr) }
        return Text(verbatim: "\(dayStr), \(pluralPayments(charges.count))")
    }

    private func pluralPayments(_ count: Int) -> String {
        String(localized: "\(count) платежей")
    }

    private static let accessibilityDayFormatter: DateFormatter = {
        PresentationLocale.dateFormatter(
            template: "d MMMM",
            calendar: CalendarViewModel.cal
        )
    }()

    // MARK: - Selected Day Section

    @ViewBuilder
    private func selectedDaySection(_ vm: CalendarViewModel) -> some View {
        let charges = vm.selectedDayOccurrences

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
                // Inline card mirrors Library row geometry so the Calendar list reads at
                // the same compact visual scale. SorenListRow is shared with Library, so
                // icon/typography/inner spacing already match — only per-row padding and
                // the surrounding card chrome needed to tighten. Not using PremiumCard
                // here: its fixed Spacing.md (16pt) jacket makes the row stack feel
                // heavier than a Library list.
                VStack(spacing: 0) {
                    ForEach(Array(charges.enumerated()), id: \.offset) { idx, occurrence in
                        Button { navigateToItem(occurrence.item) } label: {
                            let item = occurrence.item
                            if let money = occurrence.money {
                            SorenListRow(
                                title: item.title,
                                subtitle: item.providerName == item.title ? nil : item.providerName,
                                amount: money.amount,
                                currency: money.currencyCode,
                                cycle: RecurringItemFormatter.cycleLabel(for: item.billingCycle),
                                providerTemplate: item.providerTemplate,
                                category: item.category
                            )
                            .padding(.vertical, Spacing.xs)
                            .padding(.horizontal, Spacing.lg)
                            } else {
                                HStack(spacing: Spacing.sm) {
                                    if let provider = item.providerTemplate {
                                        ProviderIcon(provider: provider, size: .medium)
                                    } else {
                                        ProviderIcon(category: item.category, size: .medium)
                                    }
                                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                                        Text(item.title).font(Typography.headline).foregroundStyle(ColorTokens.textPrimary)
                                        Text(String(localized: "Пробный период"))
                                            .font(Typography.caption).foregroundStyle(ColorTokens.textTertiary)
                                    }
                                    Spacer(minLength: Spacing.xs)
                                }
                                .padding(.vertical, Spacing.xs)
                                .padding(.horizontal, Spacing.lg)
                            }
                        }
                        .buttonStyle(.plain)

                        if idx < charges.count - 1 {
                            Divider()
                                .padding(.leading, Spacing.lg + SorenListRow.dividerInset)
                        }
                    }
                }
                .background(ColorTokens.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .strokeBorder(ColorTokens.separator.opacity(0.5), lineWidth: 0.5)
                }
                .padding(.horizontal, Spacing.lg)
            }

            if vm.hasMonthlyCharges, vm.monthlyAggregation != nil {
                monthlyTotalFooter(vm: vm)
            }
        }
        .padding(.bottom, Spacing.xxxl)
        .animation(MotionTokens.snappy, value: vm.selectedDate)
    }

    private func monthlyTotalFooter(vm: CalendarViewModel) -> some View {
        Group {
            if let aggregation = vm.monthlyAggregation {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(String(localized: "Итого за месяц"))
                            .font(Typography.captionMedium)
                            .foregroundStyle(ColorTokens.textSecondary)

                        switch aggregation {
                        case let .complete(_, metadata):
                            if let metadata, case .stale = metadata.freshness {
                                Text(String(localized: "По сохранённому курсу"))
                                    .font(Typography.footnote)
                                    .foregroundStyle(ColorTokens.warning)
                            }

                        case let .partial(_, missingCodes, metadata):
                            Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                                .font(Typography.footnote)
                                .foregroundStyle(ColorTokens.warning)
                            if let metadata, case .stale = metadata.freshness {
                                Text(String(localized: "По сохранённому курсу"))
                                    .font(Typography.footnote)
                                    .foregroundStyle(ColorTokens.warning)
                            }

                        case let .unavailable(_, missingCodes, _, metadata):
                            Text(String(localized: "Курсы валют недоступны"))
                                .font(Typography.footnote)
                                .foregroundStyle(ColorTokens.textTertiary)
                            if !missingCodes.isEmpty {
                                Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                                    .font(Typography.footnote)
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                            if let metadata, case .stale = metadata.freshness {
                                Text(String(localized: "По сохранённому курсу"))
                                    .font(Typography.footnote)
                                    .foregroundStyle(ColorTokens.warning)
                            }
                        }
                    }
                    Spacer()
                    if let total = aggregation.total {
                        AmountLabel(
                            total.amount,
                            currency: total.currencyCode,
                            size: .medium
                        )
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
            }
        }
    }

    // MARK: - Helpers

    private static func dayTitle(for date: Date) -> String {
        if CalendarViewModel.cal.isDateInToday(date) {
            return String(localized: "Сегодня")
        }
        if CalendarViewModel.cal.isDateInTomorrow(date) {
            return String(localized: "Завтра")
        }
        return Self.dayFormatter
            .string(from: date)
            .capitalized(with: PresentationLocale.current)
    }

    private static let dayFormatter: DateFormatter = {
        PresentationLocale.dateFormatter(
            template: "d MMMM",
            calendar: CalendarViewModel.cal
        )
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


// MARK: - Preview

#Preview {
    CalendarView()
        .environment(
            AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
        )
}
