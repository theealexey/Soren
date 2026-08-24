import Foundation
import Testing
@testable import Soren

@Suite("CivilDate canonical storage codec")
struct CivilDateStorageCodecTests {
    private let codec = CivilDateStorageCodec()

    @Test("Encoding uses exact Gregorian UTC start of day")
    func canonicalEncoding() throws {
        let civilDate = try CivilDate(year: 2026, month: 8, day: 15)

        #expect(try codec.encode(civilDate) == Date(timeIntervalSince1970: 1_786_752_000))
    }

    @Test("Canonical value decodes to the same CivilDate")
    func canonicalDecoding() throws {
        let storedDate = Date(timeIntervalSince1970: 1_786_752_000)

        #expect(try codec.decodeCanonical(storedDate) == CivilDate(
            year: 2026,
            month: 8,
            day: 15
        ))
    }

    @Test("Encoding and decoding round-trip exactly")
    func roundTrip() throws {
        let original = try CivilDate(year: 2031, month: 12, day: 7)

        let storedDate = try codec.encode(original)

        #expect(try codec.decodeCanonical(storedDate) == original)
    }

    @Test("Gregorian leap-day round-trips")
    func leapDayRoundTrip() throws {
        let leapDay = try CivilDate(year: 2028, month: 2, day: 29)
        let storedDate = try codec.encode(leapDay)
        let decodedDate = try codec.decodeCanonical(storedDate)

        #expect(storedDate == Date(timeIntervalSince1970: 1_835_395_200))
        #expect(decodedDate == leapDay)
    }

    @Test(
        "Caller timezone does not affect canonical storage",
        arguments: [
            "Europe/Stockholm",
            "America/New_York",
            "America/Los_Angeles",
            "Asia/Tokyo",
        ]
    )
    func timezoneIndependent(_ timeZoneID: String) throws {
        var callerCalendar = Calendar(identifier: .gregorian)
        callerCalendar.locale = Locale(identifier: "en_US_POSIX")
        callerCalendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        var localComponents = DateComponents()
        localComponents.calendar = callerCalendar
        localComponents.timeZone = callerCalendar.timeZone
        localComponents.year = 2026
        localComponents.month = 8
        localComponents.day = 15
        localComponents.hour = 12
        let callerDate = try #require(callerCalendar.date(from: localComponents))
        let represented = callerCalendar.dateComponents(
            [.year, .month, .day],
            from: callerDate
        )
        let civilDate = try CivilDate(
            year: try #require(represented.year),
            month: try #require(represented.month),
            day: try #require(represented.day)
        )
        let storedDate = try codec.encode(civilDate)
        let decodedDate = try codec.decodeCanonical(storedDate)

        #expect(storedDate == Date(timeIntervalSince1970: 1_786_752_000))
        #expect(decodedDate == civilDate)
    }

    @Test(
        "Caller locale does not affect canonical storage",
        arguments: ["en_US", "ru_RU", "ja_JP"]
    )
    func localeIndependent(_ localeID: String) throws {
        var callerCalendar = Calendar(identifier: .gregorian)
        callerCalendar.locale = Locale(identifier: localeID)
        callerCalendar.timeZone = .gmt
        var localComponents = DateComponents()
        localComponents.calendar = callerCalendar
        localComponents.timeZone = callerCalendar.timeZone
        localComponents.year = 2026
        localComponents.month = 8
        localComponents.day = 15
        let callerDate = try #require(callerCalendar.date(from: localComponents))
        let represented = callerCalendar.dateComponents(
            [.year, .month, .day],
            from: callerDate
        )
        let civilDate = try CivilDate(
            year: try #require(represented.year),
            month: try #require(represented.month),
            day: try #require(represented.day)
        )

        #expect(try codec.encode(civilDate) == Date(timeIntervalSince1970: 1_786_752_000))
    }

    @Test("Civil ordering agrees with canonical persisted ordering")
    func orderingUnaffectedByEncoding() throws {
        let civilDates = [
            try CivilDate(year: 2027, month: 1, day: 1),
            try CivilDate(year: 2026, month: 12, day: 31),
            try CivilDate(year: 2026, month: 8, day: 15),
        ]

        let sortedCivilDates = civilDates.sorted()
        let encodedDates = try sortedCivilDates.map(codec.encode)

        #expect(encodedDates == encodedDates.sorted())
    }

    @Test("Noncanonical persisted values are rejected")
    func rejectsNoncanonicalValue() {
        let noncanonical = Date(timeIntervalSince1970: 1_786_752_001)

        #expect(throws: CivilDateStorageCodecError.nonCanonicalStoredDate(noncanonical)) {
            try codec.decodeCanonical(noncanonical)
        }
    }

    @Test("Legacy local midnight is not granted canonical status")
    func rejectsLegacyLocalMidnight() throws {
        var stockholm = Calendar(identifier: .gregorian)
        stockholm.locale = Locale(identifier: "en_US_POSIX")
        stockholm.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var components = DateComponents()
        components.calendar = stockholm
        components.timeZone = stockholm.timeZone
        components.year = 2026
        components.month = 8
        components.day = 15
        let legacyDate = try #require(stockholm.date(from: components))

        #expect(throws: CivilDateStorageCodecError.nonCanonicalStoredDate(legacyDate)) {
            try codec.decodeCanonical(legacyDate)
        }
    }

    @Test("Absolute timestamps remain outside codec responsibility")
    func rejectsArbitraryTimestamp() {
        let timestamp = Date(timeIntervalSince1970: 1_786_795_321.5)

        #expect(throws: CivilDateStorageCodecError.nonCanonicalStoredDate(timestamp)) {
            try codec.decodeCanonical(timestamp)
        }
    }
}
