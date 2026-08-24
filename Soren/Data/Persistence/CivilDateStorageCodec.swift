import Foundation

/// Strict Data-layer bridge between a civil billing date and its persisted representation.
/// Canonical values are encoded as Gregorian UTC start-of-day instants.
struct CivilDateStorageCodec: Sendable {
    func encode(_ civilDate: CivilDate) throws -> Date {
        var components = DateComponents()
        components.calendar = Self.gregorianCalendar
        components.timeZone = .gmt
        components.era = 1
        components.year = civilDate.year
        components.month = civilDate.month
        components.day = civilDate.day
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.nanosecond = 0

        guard let date = Self.gregorianCalendar.date(from: components) else {
            throw CivilDateStorageCodecError.encodingFailed(civilDate)
        }
        return date
    }

    func decodeCanonical(_ storedDate: Date) throws -> CivilDate {
        guard storedDate.timeIntervalSinceReferenceDate.isFinite else {
            throw CivilDateStorageCodecError.nonCanonicalStoredDate(storedDate)
        }

        let components = Self.gregorianCalendar.dateComponents(
            [.era, .year, .month, .day],
            from: storedDate
        )
        guard components.era == 1,
              let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw CivilDateStorageCodecError.nonCanonicalStoredDate(storedDate)
        }

        let civilDate: CivilDate
        do {
            civilDate = try CivilDate(year: year, month: month, day: day)
        } catch {
            throw CivilDateStorageCodecError.nonCanonicalStoredDate(storedDate)
        }

        let canonicalDate: Date
        do {
            canonicalDate = try encode(civilDate)
        } catch {
            throw CivilDateStorageCodecError.nonCanonicalStoredDate(storedDate)
        }

        guard canonicalDate == storedDate else {
            throw CivilDateStorageCodecError.nonCanonicalStoredDate(storedDate)
        }
        return civilDate
    }

    private static let gregorianCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .gmt
        return calendar
    }()
}

enum CivilDateStorageCodecError: Error, Equatable, Sendable {
    case encodingFailed(CivilDate)
    case nonCanonicalStoredDate(Date)
}
