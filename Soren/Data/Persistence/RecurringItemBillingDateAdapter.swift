import Foundation

/// Metadata, never timestamp shape, selects the interpretation of billing dates.
/// This primitive is deliberately not wired into the production mapper yet.
struct RecurringItemBillingDateAdapter: Sendable {
    static let canonicalEncodingVersion = 1

    enum Field: String, CaseIterable, Sendable {
        case startDate
        case nextChargeDate
        case trialEndDate
        case endDate
    }

    struct Dates: Equatable, Sendable {
        let startDate: Date
        let nextChargeDate: Date
        let trialEndDate: Date?
        let endDate: Date?
    }

    private let codec = CivilDateStorageCodec()

    func decode(
        _ dates: Dates,
        itemID: UUID,
        encodingVersion: Int?,
        legacyTimeZoneIdentifier: String?
    ) throws -> Dates {
        let convert: (Date, Field) throws -> Date
        if let encodingVersion {
            guard encodingVersion == Self.canonicalEncodingVersion else {
                throw RecurringItemBillingDateAdapterError.unsupportedEncodingVersion(
                    itemID: itemID, version: encodingVersion
                )
            }
            convert = { try validateCanonical($0, itemID: itemID, field: $1) }
        } else {
            guard let identifier = legacyTimeZoneIdentifier else {
                throw RecurringItemBillingDateAdapterError.missingLegacyProvenance(itemID: itemID)
            }
            guard let timeZone = TimeZone(identifier: identifier) else {
                throw RecurringItemBillingDateAdapterError.invalidLegacyTimeZoneIdentifier(
                    itemID: itemID, identifier: identifier
                )
            }
            convert = {
                try canonicalizeLegacy($0, timeZone: timeZone, itemID: itemID, field: $1)
            }
        }

        return try Dates(
            startDate: convert(dates.startDate, .startDate),
            nextChargeDate: convert(dates.nextChargeDate, .nextChargeDate),
            trialEndDate: dates.trialEndDate.map { try convert($0, .trialEndDate) },
            endDate: dates.endDate.map { try convert($0, .endDate) }
        )
    }

    /// Validates one version-1 field before future write wiring mutates a row.
    func validateCanonical(_ date: Date, itemID: UUID, field: Field) throws -> Date {
        do {
            return try codec.encode(codec.decodeCanonical(date))
        } catch {
            throw RecurringItemBillingDateAdapterError.invalidCanonicalBillingDate(
                itemID: itemID, field: field, underlying: error
            )
        }
    }

    func encode(_ civilDate: CivilDate) throws -> Date {
        try codec.encode(civilDate)
    }

    /// Recovers civil components in an explicitly supplied stored interpretation zone.
    /// Arbitrary legacy time components are valid; the input is never rewritten.
    func canonicalizeLegacy(
        _ date: Date,
        timeZone: TimeZone,
        itemID: UUID,
        field: Field
    ) throws -> Date {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw RecurringItemBillingDateAdapterError.invalidLegacyBillingDate(
                itemID: itemID, field: field, date: date
            )
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard components.era == 1,
              let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw RecurringItemBillingDateAdapterError.invalidLegacyBillingDate(
                itemID: itemID, field: field, date: date
            )
        }
        do {
            return try codec.encode(CivilDate(year: year, month: month, day: day))
        } catch {
            throw RecurringItemBillingDateAdapterError.invalidLegacyBillingDate(
                itemID: itemID, field: field, date: date
            )
        }
    }
}

enum RecurringItemBillingDateAdapterError: Error, Sendable {
    case missingLegacyProvenance(itemID: UUID)
    case invalidLegacyTimeZoneIdentifier(itemID: UUID, identifier: String)
    case unsupportedEncodingVersion(itemID: UUID, version: Int)
    case invalidLegacyBillingDate(
        itemID: UUID, field: RecurringItemBillingDateAdapter.Field, date: Date
    )
    case invalidCanonicalBillingDate(
        itemID: UUID, field: RecurringItemBillingDateAdapter.Field, underlying: Error
    )
    case invalidSuppliedTimeZoneIdentifier(String)
}
