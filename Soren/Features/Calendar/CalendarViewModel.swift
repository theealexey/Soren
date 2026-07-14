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
/// groups active subscriptions by nextChargeDate, and exposes
/// the charge list for the selected day.
@MainActor @Observable
final class CalendarViewModel {

    // MARK: - State

    private(set) var displayedMonth: Date           // first moment of the visible month
    private(set) var selectedDate: Date             // start of the tapped day
    private(set) var chargesByDate: [Date: [RecurringItem]] = [:]
    private(set) var daysInGrid: [CalendarDay] = []
    private(set) var monthlyAggregation: RecurringSpendAggregationResult?
    private(set) var selectedDayAggregation: RecurringSpendAggregationResult?
    private(set) var reportingCurrencyCode = UserPreferences.default.defaultCurrencyCode
    /// Drives one cancellable SwiftUI task per Calendar calculation.
    private(set) var aggregationRevision = 0
    private(set) var isLoaded = false
    private(set) var error: Error?

    var selectedDayCharges: [RecurringItem] {
        chargesByDate[selectedDate] ?? []
    }

    var hasMonthlyCharges: Bool {
        !monthlyProjections.isEmpty
    }

    var monthTitle: String {
        Self.monthFormatter.string(from: displayedMonth).capitalized
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

    private static let monthFormatter: DateFormatter = {
        PresentationLocale.dateFormatter(
            template: "LLLL yyyy",
            calendar: CalendarViewModel.cal
        )
    }()

    private let fetchActiveItems: @MainActor () throws -> [RecurringItem]
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
        exchangeRateProvider: Provider
    ) {
        self.fetchActiveItems = {
            try repository.fetchActive()
        }
        self.preferences = preferences
        self.aggregateRecurringSpend = aggregateRecurringSpend
        self.loadExchangeRateSnapshot = {
            try await exchangeRateProvider.latestSnapshot()
        }
        let today = Self.cal.startOfDay(for: .now)
        self.selectedDate = today
        self.displayedMonth = Self.cal.date(
            from: Self.cal.dateComponents([.year, .month], from: today)
        ) ?? today
    }

    // MARK: - Actions

    func selectDate(_ date: Date) {
        let previouslyRequiredRates = currentCalculationRequiresExchangeRates()
        selectedDate = Self.cal.startOfDay(for: date)
        rebuildAggregations(snapshot: exchangeRateSnapshot)

        if exchangeRateSnapshot == nil,
           !previouslyRequiredRates,
           currentCalculationRequiresExchangeRates() {
            aggregationRevision += 1
        }
    }

    func previousMonth() {
        guard let prev = Self.cal.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = prev
        // Reset selection to the first day of the new month so the detail section
        // always references a visible day.
        selectedDate = prev
        reloadMonth()
    }

    func nextMonth() {
        guard let next = Self.cal.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
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
            let items = try fetchActiveItems()
            let grid = buildGrid()
            let gridStart = grid.first?.date ?? displayedMonth
            let gridEnd = grid.last?.date ?? displayedMonth

            // Group charges that fall within the grid's visible date range
            var byDate: [Date: [RecurringItem]] = [:]
            for item in items {
                let day = Self.cal.startOfDay(for: item.nextChargeDate)
                if day >= gridStart && day <= gridEnd {
                    byDate[day, default: []].append(item)
                }
            }

            daysInGrid = grid
            chargesByDate = byDate

            guard let nextMonthStart = Self.cal.date(
                byAdding: .month,
                value: 1,
                to: displayedMonth
            ) else {
                assertionFailure("CalendarViewModel: failed to compute month boundaries for \(displayedMonth)")
                return
            }

            let monthRange = displayedMonth..<nextMonthStart
            displayedMonthRange = monthRange
            monthlyProjections = items.compactMap { item in
                let day = Self.cal.startOfDay(for: item.nextChargeDate)
                guard monthRange.contains(day) else { return nil }
                return projection(for: item, on: day)
            }
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

        monthlyAggregation = aggregateRecurringSpend.execute(
            projections: monthlyProjections,
            reportingCurrencyCode: reportingCurrencyCode,
            snapshot: snapshot,
            range: monthRange
        )

        guard let selectedDayEnd = Self.cal.date(
            byAdding: .day,
            value: 1,
            to: selectedDate
        ) else {
            selectedDayAggregation = nil
            return
        }

        let selectedRange = selectedDate..<selectedDayEnd
        selectedDayAggregation = aggregateRecurringSpend.execute(
            projections: selectedDayCharges.map {
                projection(for: $0, on: selectedDate)
            },
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

        guard let selectedDayEnd = Self.cal.date(
            byAdding: .day,
            value: 1,
            to: selectedDate
        ) else { return monthNeedsRates }

        let selectedRange = selectedDate..<selectedDayEnd
        let selectedNeedsRates = aggregateRecurringSpend.requiresExchangeRates(
            projections: selectedDayCharges.map {
                projection(for: $0, on: selectedDate)
            },
            reportingCurrencyCode: reportingCurrencyCode,
            range: selectedRange
        )
        return monthNeedsRates || selectedNeedsRates
    }

    private func projection(for item: RecurringItem, on date: Date) -> RecurringSpendProjection {
        RecurringSpendProjection(
            date: date,
            amount: item.amount,
            currencyCode: item.currencyCode
        )
    }

    // MARK: - Grid Construction

    private func buildGrid() -> [CalendarDay] {
        let cal = Self.cal
        let today = cal.startOfDay(for: .now)

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
