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
    /// Monthly total in `defaultCurrency` only — excludes items in other currencies.
    private(set) var monthlyTotal: Decimal = .zero
    /// True if items in other currencies were excluded from monthlyTotal.
    private(set) var hasMultiCurrencyItems = false
    private(set) var defaultCurrency: String = UserPreferences.default.defaultCurrencyCode
    private(set) var isLoaded = false
    private(set) var error: Error?

    var selectedDayCharges: [RecurringItem] {
        chargesByDate[selectedDate] ?? []
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

    private let repository: any RecurringItemRepository
    private let preferences: UserPreferencesRepository

    // MARK: - Init

    init(
        repository: any RecurringItemRepository,
        preferences: UserPreferencesRepository = UserPreferencesRepository()
    ) {
        self.repository = repository
        self.preferences = preferences
        let today = Self.cal.startOfDay(for: .now)
        self.selectedDate = today
        self.displayedMonth = Self.cal.date(
            from: Self.cal.dateComponents([.year, .month], from: today)
        ) ?? today
    }

    // MARK: - Actions

    func selectDate(_ date: Date) {
        selectedDate = date
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
        defaultCurrency = preferences.load().defaultCurrencyCode
        reloadMonth()
        // Only mark as loaded when reloadMonth did NOT produce an error.
        if error == nil { isLoaded = true }
    }

    // MARK: - Private

    private func reloadMonth() {
        error = nil
        do {
            let items = try repository.fetchActive()
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

            // Monthly total: only items in defaultCurrency to avoid cross-currency nonsense.
            // Compute monthEnd as startOfDay(last day of month) to be DST-safe.
            // Reset totals before the guard so stale values never persist on failure.
            monthlyTotal = .zero
            hasMultiCurrencyItems = false
            guard
                let nextMonthStart = Self.cal.date(byAdding: .month, value: 1, to: displayedMonth),
                let monthEndRaw = Self.cal.date(byAdding: .day, value: -1, to: nextMonthStart)
            else {
                assertionFailure("CalendarViewModel: failed to compute month boundaries for \(displayedMonth)")
                return
            }
            let monthEnd = Self.cal.startOfDay(for: monthEndRaw)

            let monthItems = items.filter { item in
                let day = Self.cal.startOfDay(for: item.nextChargeDate)
                return day >= displayedMonth && day <= monthEnd
            }
            let sameCurrencyItems = monthItems.filter { $0.currencyCode == defaultCurrency }
            monthlyTotal = sameCurrencyItems.reduce(.zero) { $0 + $1.amount }
            hasMultiCurrencyItems = monthItems.count != sameCurrencyItems.count

        } catch {
            self.error = error
        }
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
