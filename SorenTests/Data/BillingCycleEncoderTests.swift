import Testing
import Foundation
@testable import Soren

@Suite("BillingCycleEncoder — round-trip encoding")
struct BillingCycleEncoderTests {

    // MARK: - Round-trip

    @Test("Weekly round-trips correctly", arguments: [BillingCycle.weekly])
    func weeklyRoundTrip(cycle: BillingCycle) throws {
        let encoded = BillingCycleEncoder.encode(cycle)
        let decoded = try BillingCycleEncoder.decode(encoded)
        #expect(decoded == cycle)
    }

    @Test("All standard cycles round-trip without data loss")
    func allStandardCyclesRoundTrip() throws {
        let cycles: [BillingCycle] = [.weekly, .monthly, .quarterly, .semiannual, .annual]
        for cycle in cycles {
            let decoded = try BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle))
            #expect(decoded == cycle, "Failed round-trip for \(cycle)")
        }
    }

    @Test("Custom cycle round-trips with correct day count")
    func customCycleRoundTrip() throws {
        let cycle = BillingCycle.custom(days: 45)
        let encoded = BillingCycleEncoder.encode(cycle)
        let decoded = try BillingCycleEncoder.decode(encoded)
        #expect(decoded == cycle)
    }

    @Test("Custom cycle with 1 day round-trips")
    func customOneDayRoundTrip() throws {
        let cycle = BillingCycle.custom(days: 1)
        #expect(try BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle)) == cycle)
    }

    @Test("Custom cycle with large day count round-trips")
    func customLargeDaysRoundTrip() throws {
        let cycle = BillingCycle.custom(days: 999)
        #expect(try BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle)) == cycle)
    }

    // MARK: - Decode edge cases

    @Test("Unknown raw value falls back to monthly")
    func unknownRawFallsBackToMonthly() throws {
        let decoded = try BillingCycleEncoder.decode("unknown_garbage")
        #expect(decoded == .monthly)
    }

    @Test("Empty string falls back to monthly")
    func emptyStringFallback() throws {
        #expect(try BillingCycleEncoder.decode("") == .monthly)
    }

    @Test("custom: prefix without number throws a typed error")
    func customPrefixNoNumber() {
        #expect(throws: BillingCycleEncoder.DecodingError.invalidCustomCycle("custom:")) {
            try BillingCycleEncoder.decode("custom:")
        }
    }

    @Test("custom: prefix with zero days throws a typed error")
    func customZeroDaysFallback() {
        // days must be > 0 to be valid
        #expect(throws: BillingCycleEncoder.DecodingError.invalidCustomCycle("custom:0")) {
            try BillingCycleEncoder.decode("custom:0")
        }
    }

    @Test("custom: prefix with negative number throws a typed error")
    func customNegativeDaysFallback() {
        #expect(throws: BillingCycleEncoder.DecodingError.invalidCustomCycle("custom:-5")) {
            try BillingCycleEncoder.decode("custom:-5")
        }
    }

    @Test("custom: with non-integer value throws a typed error")
    func customNonIntegerFallback() {
        #expect(throws: BillingCycleEncoder.DecodingError.invalidCustomCycle("custom:abc")) {
            try BillingCycleEncoder.decode("custom:abc")
        }
    }

    @Test("Malformed and overflowing custom encodings never become monthly", arguments: [
        "custom", "custom:1:2", "custom:1.5", "custom:999999999999999999999999999999999999"
    ])
    func invalidCustomPayload(raw: String) {
        #expect(throws: BillingCycleEncoder.DecodingError.invalidCustomCycle(raw)) {
            try BillingCycleEncoder.decode(raw)
        }
    }

    @Test("Positive custom days retain the persisted representation", arguments: [1, 30, 365])
    func validCustomDays(days: Int) throws {
        let raw = "custom:\(days)"
        #expect(BillingCycleEncoder.encode(.custom(days: days)) == raw)
        #expect(try BillingCycleEncoder.decode(raw) == .custom(days: days))
    }

    @Test("Encoded weekly is lowercase 'weekly'")
    func weeklyEncodedValue() {
        #expect(BillingCycleEncoder.encode(.weekly) == "weekly")
    }

    @Test("Encoded custom format is 'custom:N'")
    func customEncodedFormat() {
        #expect(BillingCycleEncoder.encode(.custom(days: 30)) == "custom:30")
    }
}

// MARK: - Tags Encoder Tests

@Suite("TagsEncoder — comma-separated encoding")
struct TagsEncoderTests {

    @Test("Empty array encodes to empty string")
    func emptyArrayEncoding() {
        #expect(TagsEncoder.encode([]) == "")
    }

    @Test("Empty string decodes to empty array")
    func emptyStringDecoding() {
        #expect(TagsEncoder.decode("") == [])
    }

    @Test("Single tag round-trips")
    func singleTagRoundTrip() {
        let tags = ["Trial"]
        #expect(TagsEncoder.decode(TagsEncoder.encode(tags)) == tags)
    }

    @Test("Multiple tags round-trip")
    func multipleTagsRoundTrip() {
        let tags = ["Trial", "Family", "Annual"]
        #expect(TagsEncoder.decode(TagsEncoder.encode(tags)) == tags)
    }

    @Test("Tag with spaces round-trips")
    func tagWithSpacesRoundTrip() {
        let tags = ["High Cost", "Price Changed"]
        #expect(TagsEncoder.decode(TagsEncoder.encode(tags)) == tags)
    }

    @Test("Tags preserve order")
    func tagsPreserveOrder() {
        let tags = ["Z", "A", "M"]
        let result = TagsEncoder.decode(TagsEncoder.encode(tags))
        #expect(result == tags)
    }

    @Test("Russian tags round-trip")
    func russianTagsRoundTrip() {
        let tags = ["Годовой", "Семейный"]
        #expect(TagsEncoder.decode(TagsEncoder.encode(tags)) == tags)
    }
}
