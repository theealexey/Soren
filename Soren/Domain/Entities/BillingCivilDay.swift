import Foundation

/// The Date-based Domain boundary represents Gregorian billing days at UTC midnight.
/// Conversion of a known instant is a separate, explicit operation.
enum BillingCivilDay {
    static func canonicalDate(for civilDate: CivilDate) throws -> Date {
        let components = DateComponents(
            calendar: calendar, timeZone: .gmt, era: 1,
            year: civilDate.year, month: civilDate.month, day: civilDate.day,
            hour: 0, minute: 0, second: 0, nanosecond: 0
        )
        guard let date = calendar.date(from: components) else {
            throw BillingCivilDayError.unrepresentableCivilDate(civilDate)
        }
        return date
    }

    static func civilDate(fromCanonicalDate date: Date) throws -> CivilDate {
        let civilDate = try civilDate(containing: date, in: .gmt)
        guard try canonicalDate(for: civilDate) == date else {
            throw BillingCivilDayError.nonCanonicalDate(date)
        }
        return civilDate
    }

    static func civilDate(containing instant: Date, in timeZone: TimeZone) throws -> CivilDate {
        guard instant.timeIntervalSinceReferenceDate.isFinite else {
            throw BillingCivilDayError.invalidInstant(instant)
        }
        var interpretationCalendar = calendar
        interpretationCalendar.timeZone = timeZone
        let components = interpretationCalendar.dateComponents([.era, .year, .month, .day], from: instant)
        guard components.era == 1,
              let year = components.year, let month = components.month, let day = components.day else {
            throw BillingCivilDayError.invalidInstant(instant)
        }
        return try CivilDate(year: year, month: month, day: day)
    }

    /// Fixed calendar for arithmetic on canonical Domain dates, never on raw UI instants.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .gmt
        return calendar
    }

    static func days(from start: CivilDate, to end: CivilDate) throws -> Int {
        guard let days = try calendar.dateComponents(
            [.day], from: canonicalDate(for: start), to: canonicalDate(for: end)
        ).day else { throw BillingCivilDayError.arithmeticFailed }
        return days
    }
}

enum BillingCivilDayError: Error, Equatable, Sendable {
    case unrepresentableCivilDate(CivilDate)
    case nonCanonicalDate(Date)
    case invalidInstant(Date)
    case arithmeticFailed
}

/// Field context for strict Save/Update validation without changing existing business errors.
struct RecurringItemBillingDateValidationError: Error, Sendable {
    enum Field: CaseIterable, Sendable {
        case startDate, nextChargeDate, trialEndDate, endDate
    }
    let itemID: UUID
    let field: Field
    let underlying: Error
}
