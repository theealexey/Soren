import Testing
@testable import Soren

@Suite("CivilDate Gregorian domain contract")
struct CivilDateTests {
    @Test("Valid Gregorian date preserves its components")
    func validDate() throws {
        let date = try CivilDate(year: 2026, month: 8, day: 15)

        #expect(date.year == 2026)
        #expect(date.month == 8)
        #expect(date.day == 15)
    }

    @Test("Leap-day is valid in a Gregorian leap year")
    func leapDay() throws {
        let date = try CivilDate(year: 2028, month: 2, day: 29)
        let sameDate = try CivilDate(year: 2028, month: 2, day: 29)

        #expect(date == sameDate)
    }

    @Test("Non-positive year is rejected")
    func invalidYear() {
        #expect(throws: CivilDateValidationError.invalidGregorianDate(
            year: 0,
            month: 1,
            day: 1
        )) {
            try CivilDate(year: 0, month: 1, day: 1)
        }
    }

    @Test("Out-of-range month is rejected", arguments: [0, 13])
    func invalidMonth(_ month: Int) {
        #expect(throws: CivilDateValidationError.invalidGregorianDate(
            year: 2026,
            month: month,
            day: 1
        )) {
            try CivilDate(year: 2026, month: month, day: 1)
        }
    }

    @Test("Day zero is rejected")
    func dayZero() {
        #expect(throws: CivilDateValidationError.invalidGregorianDate(
            year: 2026,
            month: 8,
            day: 0
        )) {
            try CivilDate(year: 2026, month: 8, day: 0)
        }
    }

    @Test("Impossible day in a month is rejected")
    func aprilThirtyFirst() {
        #expect(throws: CivilDateValidationError.invalidGregorianDate(
            year: 2026,
            month: 4,
            day: 31
        )) {
            try CivilDate(year: 2026, month: 4, day: 31)
        }
    }

    @Test("Leap-day is rejected in a non-leap year")
    func nonLeapDay() {
        #expect(throws: CivilDateValidationError.invalidGregorianDate(
            year: 2026,
            month: 2,
            day: 29
        )) {
            try CivilDate(year: 2026, month: 2, day: 29)
        }
    }

    @Test("Comparison follows chronological civil-day order")
    func chronologicalComparison() throws {
        let earlierDay = try CivilDate(year: 2026, month: 8, day: 14)
        let laterDay = try CivilDate(year: 2026, month: 8, day: 15)
        let laterMonth = try CivilDate(year: 2026, month: 9, day: 1)
        let laterYear = try CivilDate(year: 2027, month: 1, day: 1)

        #expect(earlierDay < laterDay)
        #expect(laterDay < laterMonth)
        #expect(laterMonth < laterYear)
    }

    @Test("Equal dates have equal hashes and are Sendable")
    func equalityHashabilityAndSendability() throws {
        let first = try CivilDate(year: 2026, month: 8, day: 15)
        let second = try CivilDate(year: 2026, month: 8, day: 15)

        #expect(first == second)
        #expect(Set([first, second]).count == 1)
        requireSendable(CivilDate.self)
    }

    private func requireSendable<T: Sendable>(_: T.Type) { }
}
