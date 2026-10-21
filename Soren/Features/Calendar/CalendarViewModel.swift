import Foundation

// MARK: - Calendar Day

/// One cell in the monthly calendar grid.
struct CalendarDay: Identifiable, Hashable {
    let date: Date          // normalised to start of day
    let isCurrentMonth: Bool
    let isToday: Bool

    var id: Date { date }
}

// MARK: - Calendar View Model

/// Drives the Calendar tab.
///
/// Builds a Mon-first 7-column grid for the displayed month,
/// groups canonical schedule events by civil day.
@MainActor @Observable
final class CalendarViewModel {

    // MARK: - State

    private(set) var displayedMonth: Date           // first moment of the visible month
    private(set) var selectedDate: Date             // start of the tapped day
    private(set) var occurrencesByDay: [CivilDate: [CalendarScheduleOccurrence]] = [:]
    private(set) var chargesByDate: [Date: [RecurringItem]] = [:]
    private(set) var occurrencesByDate: [Date: [CalendarScheduleOccurrence]] = [:]
    private(set) var daysInGrid: [CalendarDay] = []
    private(set) var monthlyAggregation: RecurringSpendAggregationResult?
    private(set) var selectedDayAggregation: RecurringSpendAggregationResult?
    private(set) var reportingCurrencyCode = UserPreferences.default.defaultCurrencyCode
    /// Drives one cancellable SwiftUI task per Calendar calculation.
    private(set) var aggregationRevision = 0
    private(set) var isLoaded = false
    private(set) var error: Error?

    var selectedDayCharges: [RecurringItem] {
        selectedDayOccurrences.filter { $0.money != nil }.map(\.item)
    }

    var selectedDayOccurrences: [CalendarScheduleOccurrence] {
        guard let day = try? BillingCivilDay.civilDate(containing: selectedDate, in: calendar.timeZone) else { return [] }
        return occurrencesByDay[day] ?? []
    }

    var canNavigatePreviousMonth: Bool {
        guard let today = try? BillingCivilDay.civilDate(containing: now(), in: calendar.timeZone),
              let displayed = try? BillingCivilDay.civilDate(containing: displayedMonth, in: calendar.timeZone) else { return false }
        return displayed.year > today.year || (displayed.year == today.year && displayed.month > today.month)
    }

    var hasMonthlyCharges: Bool {
        !monthlyProjections.isEmpty
    }

    /// Read-only UI carrier calendar; schedule calculations remain canonical.
    var presentationCalendar: Calendar { calendar }

    var hasMonthlyEvents: Bool { !occurrencesByDay.isEmpty }

    var monthTitle: String {
        monthTitle(locale: PresentationLocale.current)
    }

    func monthTitle(locale: Locale) -> String {
        let formatter = PresentationLocale.dateFormatter(template: "LLLL yyyy", locale: locale, calendar: calendar)
        formatter.timeZone = calendar.timeZone
        let title = formatter.string(from: displayedMonth)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
        return title.prefix(1).uppercased(with: locale) + title.dropFirst()
    }

    // MARK: - Private

    /// Single Gregorian calendar with the app language and Mon-first week used consistently
    /// throughout this ViewModel. Using one instance prevents Calendar.current (which may
    /// be non-Gregorian on CIS devices using Islamic or Persian system calendars) from
    /// being mixed into date arithmetic.
    static let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = PresentationLocale.current
        c.firstWeekday = 2  // Monday
        return c
    }()

    private let getSchedule: GetCalendarSchedule
    private let now: () -> Date
    private let calendar: Calendar
    private var scheduleMonetaryCompleteness = RecurringScheduleProjection.MonetaryCompleteness.complete
    private let preferences: UserPreferencesRepository
    private let aggregateRecurringSpend: AggregateRecurringSpendUseCase
    private let loadExchangeRateSnapshot: @Sendable () async throws -> ExchangeRateSnapshot

    private var monthlyProjections: [RecurringSpendProjection] = []
    private var displayedMonthRange: Range<Date>?
    private var exchangeRateSnapshot: ExchangeRateSnapshot?
    private var inFlightRevision: Int?

    // MARK: - Init

    init<Repository: RecurringItemRepository, Provider: ExchangeRateProvider>(
        repository: Repository,
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        aggregateRecurringSpend: AggregateRecurringSpendUseCase = AggregateRecurringSpendUseCase(),
        exchangeRateProvider: Provider,
        now: @escaping () -> Date = { .now },
        calendar: Calendar = CalendarViewModel.cal
    ) {
        self.getSchedule = GetCalendarSchedule(repository: repository)
        self.now = now
        var presentationCalendar = Calendar(identifier: .gregorian)
        presentationCalendar.timeZone = calendar.timeZone
        presentationCalendar.locale = PresentationLocale.current
        presentationCalendar.firstWeekday = 2
        self.calendar = presentationCalendar
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.loadExchangeRateSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
        let today = presentationCalendar.startOfDay(for: now())
        self.selectedDate = today
        self.displayedMonth = presentationCalendar.date(
            from: presentationCalendar.dateComponents([.year, .month], from: today)
        ) ?? today
    }

    // MARK: - Actions

    func selectDate(_ date: Date) {
        let previouslyRequiredRates = currentCalculationRequiresExchangeRates()
        selectedDate = calendar.startOfDay(for: date)
        rebuildAggregations(snapshot: exchangeRateSnapshot)

        if exchangeRateSnapshot == nil,
           !previouslyRequiredRates,
           currentCalculationRequiresExchangeRates() {
            aggregationRevision += 1
        }
    }

    func previousMonth() {
        guard canNavigatePreviousMonth,
              let prev = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = prev
        // Reset selection to the first day of the new month so the detail section
        // always references a visible day.
        selectedDate = prev
        reloadMonth()
    }

    func nextMonth() {
        guard let next = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        selectedDate = next
        reloadMonth()
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        reportingCurrencyCode = preferences.load().defaultCurrencyCode
        reloadMonth()
        // Only mark as loaded when reloadMonth did NOT produce an error.
        if error == nil { isLoaded = true }
    }

    /// Loads at most one snapshot for the current calculation. The revision guard
    /// prevents an older month/currency request from overwriting newer Calendar state.
    func refreshCurrencyAggregation(revision: Int) async {
        guard revision == aggregationRevision,
              currentCalculationRequiresExchangeRates(),
              inFlightRevision != revision
        else { return }

        inFlightRevision = revision
        defer {
            if inFlightRevision == revision {
                inFlightRevision = nil
            }
        }

        do {
            let snapshot = try await loadExchangeRateSnapshot()
            guard !Task.isCancelled, revision == aggregationRevision else { return }
            exchangeRateSnapshot = snapshot
            rebuildAggregations(snapshot: snapshot)
        } catch is CancellationError {
            return
        } catch {
            // Existing events stay visible. The no-snapshot result is already a
            // truthful partial/unavailable state and never a raw mixed-currency sum.
        }
    }

    // MARK: - Private

    private func reloadMonth() {
        aggregationRevision += 1
        exchangeRateSnapshot = nil
        error = nil
        do {
            let today = try BillingCivilDay.civilDate(containing: now(), in: calendar.timeZone)
            var month = try BillingCivilDay.civilDate(containing: displayedMonth, in: calendar.timeZone)
            if month.year < today.year || (month.year == today.year && month.month < today.month) {
                let first = try CivilDate(year: today.year, month: today.month, day: 1)
                displayedMonth = try Self.gridDay(for: BillingCivilDay.canonicalDate(for: first), calendar: calendar)
                selectedDate = displayedMonth
                month = first
            }
            let schedule = try getSchedule.execute(month: month, today: today)
            let grouped = Dictionary(grouping: schedule.occurrences, by: \.day)
            var carriers: [Date: [RecurringItem]] = [:]
            var occurrenceCarriers: [Date: [CalendarScheduleOccurrence]] = [:]
            for (day, events) in grouped {
                let date = try Self.gridDay(for: BillingCivilDay.canonicalDate(for: day), calendar: calendar)
                carriers[date] = events.filter { $0.money != nil }.map(\.item)
                occurrenceCarriers[date] = events
            }
            let grid = buildGrid()
            daysInGrid = grid
            occurrencesByDay = grouped
            chargesByDate = carriers
            occurrencesByDate = occurrenceCarriers
            displayedMonthRange = schedule.range
            scheduleMonetaryCompleteness = schedule.monetaryCompleteness
            monthlyProjections = try projections(for: schedule.occurrences)
            rebuildAggregations(snapshot: exchangeRateSnapshot)

        } catch {
            self.error = error
        }
    }

    private func rebuildAggregations(snapshot: ExchangeRateSnapshot?) {
        guard let monthRange = displayedMonthRange else {
            monthlyAggregation = nil
            selectedDayAggregation = nil
            return
        }

        monthlyAggregation = scheduleMonetaryCompleteness == .complete ? aggregateRecurringSpend.execute(
            projections: monthlyProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: monthRange
        ) : nil

        guard let selectedDay = try? BillingCivilDay.civilDate(containing: selectedDate, in: calendar.timeZone),
              let selectedStart = try? BillingCivilDay.canonicalDate(for: selectedDay),
              let selectedDayEnd = BillingCivilDay.calendar.date(
            byAdding: .day,
            value: 1,
            to: selectedStart
        ) else {
            selectedDayAggregation = nil
            return
        }

        let selectedRange = selectedStart..<selectedDayEnd
        selectedDayAggregation = aggregateRecurringSpend.execute(
            projections: monthlyProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: selectedRange
        )
    }

    private func currentCalculationRequiresExchangeRates() -> Bool {
        let monthNeedsRates: Bool
        if let monthRange = displayedMonthRange {
            monthNeedsRates = aggregateRecurringSpend.requiresExchangeRates(
                projections: monthlyProjections,
                reportingCurrencyCode: reportingCurrencyCode,
                range: monthRange
            )
        } else {
            monthNeedsRates = false
        }

        return monthNeedsRates
    }

    private func projections(for occurrences: [CalendarScheduleOccurrence]) throws -> [RecurringSpendProjection] {
        try occurrences.compactMap { occurrence in
            guard let money = occurrence.money else { return nil }
            return RecurringSpendProjection(date: try BillingCivilDay.canonicalDate(for: occurrence.day),
                                            amount: money.amount, currencyCode: money.currencyCode)
        }
    }

    static func gridDay(for canonicalDate: Date, calendar: Calendar) throws -> Date {
        let day = try BillingCivilDay.civilDate(fromCanonicalDate: canonicalDate)
        let carrier = try BillingDatePresentation.pickerCarrier(for: day, in: calendar.timeZone)
        return calendar.startOfDay(for: carrier)
    }

    // MARK: - Grid Construction

    private func buildGrid() -> [CalendarDay] {
        let cal = calendar
        let today = cal.startOfDay(for: now())

        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth)),
            let monthRange = cal.range(of: .day, in: .month, for: monthStart),
            let monthEnd = cal.date(byAdding: .day, value: monthRange.count - 1, to: monthStart)
        else { return [] }

        // Convert raw weekday (1=Sun…7=Sat) to Mon-based column offset (Mon=0…Sun=6)
        let rawWeekday = cal.component(.weekday, from: monthStart)
        let prefixCount = (rawWeekday - 2 + 7) % 7

        var days: [CalendarDay] = []

        // Padding cells from previous month
        for offset in stride(from: prefixCount, through: 1, by: -1) {
            if let d = cal.date(byAdding: .day, value: -offset, to: monthStart) {
                days.append(CalendarDay(
                    date: cal.startOfDay(for: d),
                    isCurrentMonth: false,
                    isToday: cal.isDate(d, inSameDayAs: today)
                ))
            }
        }

        // Days of the current month
        for i in 0..<monthRange.count {
            if let d = cal.date(byAdding: .day, value: i, to: monthStart) {
                days.append(CalendarDay(
                    date: cal.startOfDay(for: d),
                    isCurrentMonth: true,
                    isToday: cal.isDate(d, inSameDayAs: today)
                ))
            }
        }

        // Trailing padding to complete the final row
        let remainder = days.count % 7
        if remainder != 0 {
            for i in 1...(7 - remainder) {
                if let d = cal.date(byAdding: .day, value: i, to: monthEnd) {
                    days.append(CalendarDay(
                        date: cal.startOfDay(for: d),
                        isCurrentMonth: false,
                        isToday: cal.isDate(d, inSameDayAs: today)
                    ))
                }
            }
        }

        return days
    }
}
