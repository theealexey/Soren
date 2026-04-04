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
    private(set) var monthlyTotal: Decimal = .zero
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

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
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
        let today = Calendar.current.startOfDay(for: .now)
        self.selectedDate = today
        self.displayedMonth = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: today)
        ) ?? today
    }

    // MARK: - Actions

    func selectDate(_ date: Date) {
        selectedDate = date
    }

    func previousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = prev
        reloadMonth()
    }

    func nextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        reloadMonth()
    }

    // MARK: - Load

    func load(forceReload: Bool = false) {
        guard !isLoaded || forceReload else { return }
        defaultCurrency = preferences.load().defaultCurrencyCode
        reloadMonth()
        isLoaded = true
    }

    // MARK: - Private

    private func reloadMonth() {
        error = nil
        do {
            let items = try repository.fetchActive()
            let grid = buildGrid()
            let gridStart = grid.first?.date ?? displayedMonth
            let gridEnd = grid.last?.date ?? displayedMonth

            // Group charges falling within the grid's visible date range
            var byDate: [Date: [RecurringItem]] = [:]
            for item in items {
                let day = Calendar.current.startOfDay(for: item.nextChargeDate)
                if day >= gridStart && day <= gridEnd {
                    byDate[day, default: []].append(item)
                }
            }

            daysInGrid = grid
            chargesByDate = byDate

            // Monthly total: items whose charge falls in the displayed month
            guard
                let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth),
                let monthEnd = Calendar.current.date(byAdding: .day, value: -1, to: nextMonth)
            else { return }

            monthlyTotal = items.filter { item in
                let day = Calendar.current.startOfDay(for: item.nextChargeDate)
                return day >= displayedMonth && day <= monthEnd
            }.reduce(.zero) { $0 + $1.amount }

        } catch {
            self.error = error
        }
    }

    // MARK: - Grid Construction

    private func buildGrid() -> [CalendarDay] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2   // Monday

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
