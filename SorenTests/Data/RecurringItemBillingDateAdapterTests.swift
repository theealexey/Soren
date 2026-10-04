import Foundation
import Testing
@testable import Soren

@Suite("Recurring item billing-date adapter")
struct RecurringItemBillingDateAdapterTests {
    private let adapter = RecurringItemBillingDateAdapter()
    private let itemID = UUID(uuid: (
        0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x41, 0x11,
        0x81, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11
    ))
    private let canonical = Date(timeIntervalSince1970: 1_786_752_000)

    @Test("Version 1 returns all required and optional canonical fields")
    func canonicalRecord() throws {
        let input = dates(canonical, optionalDates: true)
        let output = try adapter.decode(
            input, itemID: itemID, encodingVersion: 1, legacyTimeZoneIdentifier: nil
        )
        #expect(output == input)
        #expect(try CivilDateStorageCodec().decodeCanonical(output.nextChargeDate)
            == CivilDate(year: 2026, month: 8, day: 15))
    }

    @Test("Version 1 rejects a noncanonical field", arguments: RecurringItemBillingDateAdapter.Field.allCases)
    func noncanonicalField(_ field: RecurringItemBillingDateAdapter.Field) {
        let invalid = canonical.addingTimeInterval(1)
        let input = RecurringItemBillingDateAdapter.Dates(
            startDate: field == .startDate ? invalid : canonical,
            nextChargeDate: field == .nextChargeDate ? invalid : canonical,
            trialEndDate: field == .trialEndDate ? invalid : canonical,
            endDate: field == .endDate ? invalid : canonical
        )
        do {
            _ = try adapter.decode(
                input, itemID: itemID, encodingVersion: 1,
                legacyTimeZoneIdentifier: "Europe/Stockholm"
            )
            Issue.record("Expected strict canonical field failure")
        } catch RecurringItemBillingDateAdapterError.invalidCanonicalBillingDate(
            let failedID, let failedField, let underlying
        ) {
            #expect(failedID == itemID)
            #expect(failedField == field)
            #expect(underlying as? CivilDateStorageCodecError == .nonCanonicalStoredDate(invalid))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Version 1 ignores even invalid provenance", arguments: ["", "Not/AZone", "America/New_York"])
    func canonicalIgnoresProvenance(_ identifier: String) throws {
        #expect(try adapter.decode(
            dates(canonical), itemID: itemID, encodingVersion: 1,
            legacyTimeZoneIdentifier: identifier
        ).nextChargeDate == canonical)
    }

    @Test("Unknown version fails before date or provenance interpretation", arguments: [-1, 0, 2, 999])
    func unknownVersion(_ version: Int) {
        do {
            _ = try adapter.decode(
                dates(Date(timeIntervalSince1970: .nan)), itemID: itemID,
                encodingVersion: version, legacyTimeZoneIdentifier: "Not/AZone"
            )
            Issue.record("Expected unsupported version")
        } catch RecurringItemBillingDateAdapterError.unsupportedEncodingVersion(let failedID, let value) {
            #expect(failedID == itemID)
            #expect(value == version)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Legacy Stockholm fixture day becomes UTC midnight")
    func stockholmLegacy() throws {
        let legacy = Date(timeIntervalSince1970: 1_786_744_800)
        let input = dates(legacy, optionalDates: true)
        let output = try adapter.decode(
            input, itemID: itemID, encodingVersion: nil,
            legacyTimeZoneIdentifier: "Europe/Stockholm"
        )
        #expect(output == dates(canonical, optionalDates: true))
        #expect(input.startDate == legacy)
    }

    @Test("Legacy New York fixture day becomes UTC midnight")
    func newYorkLegacy() throws {
        let input = dates(Date(timeIntervalSince1970: 1_767_243_600), optionalDates: true)
        let expected = Date(timeIntervalSince1970: 1_767_225_600)
        #expect(try adapter.decode(
            input, itemID: itemID, encodingVersion: nil,
            legacyTimeZoneIdentifier: "America/New_York"
        ) == dates(expected, optionalDates: true))
    }

    @Test("Legacy metadata remains authoritative even for a UTC-midnight timestamp")
    func noTimestampHeuristic() throws {
        let output = try adapter.decode(
            dates(canonical), itemID: itemID, encodingVersion: nil,
            legacyTimeZoneIdentifier: "America/New_York"
        )
        #expect(output.startDate == Date(timeIntervalSince1970: 1_786_665_600))
        #expect(output.startDate != canonical)
    }

    @Test("Missing provenance never falls back even for canonical-looking dates")
    func missingProvenance() {
        do {
            _ = try adapter.decode(
                dates(canonical), itemID: itemID, encodingVersion: nil, legacyTimeZoneIdentifier: nil
            )
            Issue.record("Expected missing provenance")
        } catch RecurringItemBillingDateAdapterError.missingLegacyProvenance(let failedID) {
            #expect(failedID == itemID)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Malformed provenance has a typed failure", arguments: ["", "Not/AZone"])
    func invalidProvenance(_ identifier: String) {
        do {
            _ = try adapter.decode(
                dates(canonical), itemID: itemID, encodingVersion: nil,
                legacyTimeZoneIdentifier: identifier
            )
            Issue.record("Expected invalid provenance")
        } catch RecurringItemBillingDateAdapterError.invalidLegacyTimeZoneIdentifier(let failedID, let value) {
            #expect(failedID == itemID)
            #expect(value == identifier)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Optional dates stay nil in both supported metadata states", arguments: [false, true])
    func optionalNil(_ isCanonical: Bool) throws {
        let output = try adapter.decode(
            dates(canonical), itemID: itemID, encodingVersion: isCanonical ? 1 : nil,
            legacyTimeZoneIdentifier: isCanonical ? nil : "Europe/Stockholm"
        )
        #expect(output.trialEndDate == nil)
        #expect(output.endDate == nil)
    }

    @Test("Unrelated caller timezone assumptions cannot change stored-provenance decoding",
          arguments: ["America/Los_Angeles", "Asia/Tokyo", "Europe/Moscow"])
    func callerTimezoneIndependent(_ callerIdentifier: String) throws {
        let legacy = Date(timeIntervalSince1970: 1_786_744_800)
        var callerCalendar = Calendar(identifier: .gregorian)
        callerCalendar.timeZone = try #require(TimeZone(identifier: callerIdentifier))
        let callerDay = callerCalendar.component(.day, from: legacy)
        if callerIdentifier == "America/Los_Angeles" {
            #expect(callerDay == 14)
        } else {
            #expect(callerDay == 15)
        }
        // The caller's calendar is deliberately not an adapter dependency.
        #expect(try adapter.decode(
            dates(legacy), itemID: itemID, encodingVersion: nil,
            legacyTimeZoneIdentifier: "Europe/Stockholm"
        ).startDate == canonical)
    }

    @Test("Legacy timestamps need not be at local midnight")
    func arbitraryLegacyTime() throws {
        let legacy = Date(timeIntervalSince1970: 1_786_744_800 + 13 * 3_600 + 27)
        let output = try adapter.decode(
            dates(legacy), itemID: itemID, encodingVersion: nil,
            legacyTimeZoneIdentifier: "Europe/Stockholm"
        )
        #expect(output.nextChargeDate == canonical)
    }

    @Test("Invalid legacy dates produce field-specific typed failure",
          arguments: [Double.nan, Double.infinity, -62_167_219_200])
    func invalidLegacyDate(_ seconds: Double) {
        do {
            _ = try adapter.decode(
                dates(Date(timeIntervalSince1970: seconds)), itemID: itemID,
                encodingVersion: nil, legacyTimeZoneIdentifier: "Europe/Stockholm"
            )
            Issue.record("Expected invalid legacy billing date")
        } catch RecurringItemBillingDateAdapterError.invalidLegacyBillingDate(let failedID, let field, let date) {
            #expect(failedID == itemID)
            #expect(field == .startDate)
            #expect(date.timeIntervalSince1970.isNaN == seconds.isNaN)
            if seconds.isNaN == false { #expect(date.timeIntervalSince1970 == seconds) }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Write support reuses the strict codec and an explicit legacy timezone")
    func writeSupport() throws {
        #expect(try adapter.encode(CivilDate(year: 2026, month: 8, day: 15)) == canonical)
        #expect(try adapter.validateCanonical(canonical, itemID: itemID, field: .nextChargeDate) == canonical)
        #expect(try adapter.canonicalizeLegacy(
            Date(timeIntervalSince1970: 1_786_744_800),
            timeZone: #require(TimeZone(identifier: "Europe/Stockholm")),
            itemID: itemID, field: .trialEndDate
        ) == canonical)
    }

    @Test("Write validation rejects arbitrary timestamps")
    func invalidCanonicalWrite() {
        do {
            _ = try adapter.validateCanonical(
                canonical.addingTimeInterval(0.5), itemID: itemID, field: .endDate
            )
            Issue.record("Expected canonical write rejection")
        } catch RecurringItemBillingDateAdapterError.invalidCanonicalBillingDate(let failedID, let field, _) {
            #expect(failedID == itemID)
            #expect(field == .endDate)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func dates(_ date: Date, optionalDates: Bool = false) -> RecurringItemBillingDateAdapter.Dates {
        .init(
            startDate: date, nextChargeDate: date,
            trialEndDate: optionalDates ? date : nil, endDate: optionalDates ? date : nil
        )
    }
}
