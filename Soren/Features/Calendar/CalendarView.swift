import SwiftUI

/// Presentation only; SOR-105A owns canonical occurrence projection and money.
struct CalendarView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.navigateToItem) private var navigateToItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel: CalendarViewModel?
    @ScaledMetric(relativeTo: .headline) private var headingSize = 17.0
    @ScaledMetric(relativeTo: .caption2) private var weekdaySize = 11.0
    @ScaledMetric(relativeTo: .subheadline) private var emptySize = 14.0

    var body: some View {
        Group {
            if let vm = viewModel {
                calendarContent(vm)
            } else {
                LoadingStateView()
            }
        }
        .background(SoftClubColor.canvas.ignoresSafeArea())
        .task(id: container.refreshIdentity) {
            if viewModel == nil { viewModel = container.makeCalendarViewModel() }
            viewModel?.load(forceReload: true)
        }
    }

    @ViewBuilder private func calendarContent(_ vm: CalendarViewModel) -> some View {
        Group {
            if vm.error != nil {
                ErrorStateView(message: "Не удалось загрузить данные") {
                    vm.load(forceReload: true)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        monthHeader(vm)
                        weekdayHeader(calendar: vm.presentationCalendar)
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                        calendarGrid(vm)
                        CalendarMonthSummary(aggregation: vm.monthlyAggregation, hasEvents: vm.hasMonthlyEvents)
                            .padding(.top, 12)
                        selectedDaySection(vm)
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .task(id: vm.aggregationRevision) {
            let revision = vm.aggregationRevision
            await vm.refreshCurrencyAggregation(revision: revision)
        }
    }

    private func monthHeader(_ vm: CalendarViewModel) -> some View {
        ZStack {
            Text(vm.monthTitle)
                .font(.system(size: headingSize, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .accessibilityAddTraits(.isHeader)
                .accessibilitySortPriority(3)
            HStack(spacing: 0) {
                Button {
                    HapticEngine.selection()
                    vm.previousMonth()
                } label: {
                    navigationSymbol("chevron.left", enabled: vm.canNavigatePreviousMonth)
                }
                .disabled(!vm.canNavigatePreviousMonth)
                .accessibilityLabel(String(localized: "Предыдущий месяц"))
                .accessibilitySortPriority(2)
                Spacer(minLength: 0)
                Button {
                    HapticEngine.selection()
                    vm.nextMonth()
                } label: {
                    navigationSymbol("chevron.right", enabled: true)
                }
                .accessibilityLabel(String(localized: "Следующий месяц"))
                .accessibilitySortPriority(1)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? headingSize * 2.5 : 44)
        .accessibilityElement(children: .contain)
    }

    private func navigationSymbol(_ name: String, enabled: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(enabled ? SoftClubColor.textPrimary : SoftClubColor.textSecondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private func weekdayHeader(calendar: Calendar) -> some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let labels = Array(symbols.dropFirst()) + Array(symbols.prefix(1))
        return HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.system(size: weekdaySize, weight: .medium))
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true) // Every day button speaks its full weekday and date.
    }

    private func calendarGrid(_ vm: CalendarViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
            ForEach(vm.daysInGrid) { day in
                let selected = vm.presentationCalendar.isDate(day.date, inSameDayAs: vm.selectedDate)
                let events = vm.occurrencesByDate[day.date] ?? []
                CalendarDayCell(
                    presentation: CalendarDayPresentation(day: day, isSelected: selected, occurrences: events),
                    calendar: vm.presentationCalendar
                ) {
                    vm.selectDate(day.date)
                    if !events.isEmpty { HapticEngine.selection() }
                }
            }
        }
    }

    private func selectedDaySection(_ vm: CalendarViewModel) -> some View {
        let day = vm.daysInGrid.first { vm.presentationCalendar.isDate($0.date, inSameDayAs: vm.selectedDate) }
        return VStack(alignment: .leading, spacing: 10) {
            if let day {
                Text(CalendarPresentation.selectedDayTitle(day: day, calendar: vm.presentationCalendar))
                    .font(.system(size: headingSize, weight: .semibold))
                    .foregroundStyle(SoftClubColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)
            }
            if vm.selectedDayOccurrences.isEmpty {
                Text(String(localized: "calendar.emptySelectedDay"))
                    .font(.system(size: emptySize, weight: .regular))
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                CalendarAgendaView(occurrences: vm.selectedDayOccurrences, openItem: { navigateToItem($0) })
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
