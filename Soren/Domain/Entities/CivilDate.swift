import Foundation

/// A Gregorian calendar date without a clock time or timezone.
struct CivilDate: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) throws {
        guard year > 0 else {
            throw CivilDateValidationError.invalidGregorianDate(
                year: year,
                month: month,
                day: day
            )
        }

        var components = DateComponents()
        components.calendar = Self.gregorianCalendar
        components.timeZone = .gmt
        components.era = 1
        components.year = year
        components.month = month
        components.day = day

        guard let date = Self.gregorianCalendar.date(from: components) else {
            throw CivilDateValidationError.invalidGregorianDate(
                year: year,
                month: month,
                day: day
            )
        }

        let validated = Self.gregorianCalendar.dateComponents(
            [.era, .year, .month, .day],
            from: date
        )
        guard validated.era == 1,
              validated.year == year,
              validated.month == month,
              validated.day == day else {
            throw CivilDateValidationError.invalidGregorianDate(
                year: year,
                month: month,
                day: day
            )
        }

        self.year = year
        self.month = month
        self.day = day
    }

    static func < (lhs: CivilDate, rhs: CivilDate) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        }
        if lhs.month != rhs.month {
            return lhs.month < rhs.month
        }
        return lhs.day < rhs.day
    }

    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .gmt
        return calendar
    }()
}

enum CivilDateValidationError: Error, Equatable, Sendable {
    case invalidGregorianDate(year: Int, month: Int, day: Int)
}
