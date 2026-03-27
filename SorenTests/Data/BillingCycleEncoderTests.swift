import Testing
import Foundation
@testable import Soren

@Suite("BillingCycleEncoder — round-trip encoding")
struct BillingCycleEncoderTests {

    // MARK: - Round-trip

    @Test("Weekly round-trips correctly", arguments: [BillingCycle.weekly])
    func weeklyRoundTrip(cycle: BillingCycle) {
        let encoded = BillingCycleEncoder.encode(cycle)
        let decoded = BillingCycleEncoder.decode(encoded)
        #expect(decoded == cycle)
    }

    @Test("All standard cycles round-trip without data loss")
    func allStandardCyclesRoundTrip() {
        let cycles: [BillingCycle] = [.weekly, .monthly, .quarterly, .semiannual, .annual]
        for cycle in cycles {
            let decoded = BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle))
            #expect(decoded == cycle, "Failed round-trip for \(cycle)")
        }
    }

    @Test("Custom cycle round-trips with correct day count")
    func customCycleRoundTrip() {
        let cycle = BillingCycle.custom(days: 45)
        let encoded = BillingCycleEncoder.encode(cycle)
        let decoded = BillingCycleEncoder.decode(encoded)
        #expect(decoded == cycle)
    }

    @Test("Custom cycle with 1 day round-trips")
    func customOneDayRoundTrip() {
        let cycle = BillingCycle.custom(days: 1)
        #expect(BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle)) == cycle)
    }

    @Test("Custom cycle with large day count round-trips")
    func customLargeDaysRoundTrip() {
        let cycle = BillingCycle.custom(days: 999)
        #expect(BillingCycleEncoder.decode(BillingCycleEncoder.encode(cycle)) == cycle)
    }

    // MARK: - Decode edge cases

    @Test("Unknown raw value falls back to monthly")
    func unknownRawFallsBackToMonthly() {
        let decoded = BillingCycleEncoder.decode("unknown_garbage")
        #expect(decoded == .monthly)
    }

    @Test("Empty string falls back to monthly")
    func emptyStringFallback() {
        #expect(BillingCycleEncoder.decode("") == .monthly)
    }

    @Test("custom: prefix without number falls back to monthly")
    func customPrefixNoNumber() {
        #expect(BillingCycleEncoder.decode("custom:") == .monthly)
    }

    @Test("custom: prefix with zero days falls back to monthly")
    func customZeroDaysFallback() {
        // days must be > 0 to be valid
        #expect(BillingCycleEncoder.decode("custom:0") == .monthly)
    }

    @Test("custom: prefix with negative number falls back to monthly")
    func customNegativeDaysFallback() {
        #expect(BillingCycleEncoder.decode("custom:-5") == .monthly)
    }

    @Test("custom: with non-integer value falls back to monthly")
    func customNonIntegerFallback() {
        #expect(BillingCycleEncoder.decode("custom:abc") == .monthly)
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
