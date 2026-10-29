import Foundation

// MARK: - Recurring Item Mapper

/// Converts between the SwiftData storage model (SDRecurringItem)
/// and the Domain entity (RecurringItem).
///
/// All conversion logic lives here — both @Model and Domain struct remain clean.
enum RecurringItemMapper {

    // MARK: - SD → Domain

    static func toDomain(_ sd: SDRecurringItem) throws -> RecurringItem {
        let dates = try decodedBillingDates(sd)
        let deadline = try sd.renewalDecisionDeadline.map(CivilDateStorageCodec().decodeCanonical)
        let item = RecurringItem(
            id: sd.id,
            title: sd.title,
            providerID: sd.providerID,
            providerName: sd.providerName,
            itemType: ItemType(rawValue: sd.itemTypeRaw) ?? .otherRecurring,
            category: ItemCategory(rawValue: sd.categoryRaw) ?? .other,
            amount: sd.amountValue,
            currencyCode: sd.currencyCode,
            billingCycle: try BillingCycleEncoder.decode(sd.billingCycleRaw),
            startDate: dates.startDate,
            nextChargeDate: dates.nextChargeDate,
            trialEndDate: dates.trialEndDate,
            autoRenew: sd.autoRenew ?? true,   // nil = legacy record → treat as auto-renewing
            endDate: dates.endDate,
            renewalDecisionDeadline: deadline,
            renewalDecisionReminderEnabled: sd.renewalDecisionReminderEnabled ?? false,
            chargeReminder: sd.chargeReminderRaw.flatMap(ChargeReminderOption.init) ?? .threeDaysBefore,
            trialReminder: sd.trialReminderRaw.flatMap(TrialReminderOption.init) ?? .never,
            status: ItemStatus(rawValue: sd.statusRaw) ?? .active,
            usageStatus: UsageStatus(rawValue: sd.usageStatusRaw) ?? .unknown,
            paymentMethodID: sd.paymentMethodID,
            note: sd.note,
            tags: TagsEncoder.decode(sd.tagsRaw),
            isShared: sd.isShared,
            isFamilyPlan: sd.isFamilyPlan,
            bundleID: sd.bundleID,
            managementURL: sd.managementURL,
            createdAt: sd.createdAt,
            updatedAt: sd.updatedAt,
            archivedAt: sd.archivedAt
        )
        try item.validateRenewalDecision()
        return item
    }

    // MARK: - Domain → SD (new)

    static func toSD(_ domain: RecurringItem) throws -> SDRecurringItem {
        let dates = try preparedBillingDates(domain)
        let renewal = try preparedRenewalDecision(domain)
        let sd = SDRecurringItem(
            id: domain.id,
            title: domain.title,
            providerID: domain.providerID,
            providerName: domain.providerName,
            itemTypeRaw: domain.itemType.rawValue,
            categoryRaw: domain.category.rawValue,
            amountValue: domain.amount,
            currencyCode: domain.currencyCode,
            billingCycleRaw: BillingCycleEncoder.encode(domain.billingCycle),
            startDate: dates.startDate,
            nextChargeDate: dates.nextChargeDate,
            trialEndDate: dates.trialEndDate,
            autoRenew: domain.autoRenew,
            endDate: dates.endDate,
            chargeReminderRaw: domain.chargeReminder.rawValue,
            trialReminderRaw: domain.trialReminder.rawValue,
            statusRaw: domain.status.rawValue,
            usageStatusRaw: domain.usageStatus.rawValue,
            paymentMethodID: domain.paymentMethodID,
            note: domain.note,
            tagsRaw: TagsEncoder.encode(domain.tags),
            isShared: domain.isShared,
            isFamilyPlan: domain.isFamilyPlan,
            bundleID: domain.bundleID,
            managementURL: domain.managementURL,
            createdAt: domain.createdAt,
            updatedAt: domain.updatedAt,
            archivedAt: domain.archivedAt
        )
        sd.renewalDecisionDeadline = renewal.deadline
        sd.renewalDecisionReminderEnabled = renewal.reminderEnabled
        sd.billingDateEncodingVersion = RecurringItemBillingDateAdapter.canonicalEncodingVersion
        return sd
    }

    // MARK: - Domain → SD (update existing)

    /// Updates an existing SDRecurringItem in-place from a domain entity.
    /// Used by the Repository's `update` method — avoids deleting/reinserting.
    static func update(_ sd: SDRecurringItem, from domain: RecurringItem) throws {
        // Prove the persisted tuple is readable, then prepare the entire replacement
        // before the first managed mutation. Metadata, not date equality, chooses decoding.
        _ = try decodedBillingDates(sd)
        _ = try sd.renewalDecisionDeadline.map(CivilDateStorageCodec().decodeCanonical)
        let dates = try preparedBillingDates(domain)
        let renewal = try preparedRenewalDecision(domain)
        sd.renewalDecisionDeadline = renewal.deadline
        sd.renewalDecisionReminderEnabled = renewal.reminderEnabled
        sd.title = domain.title
        sd.providerID = domain.providerID
        sd.providerName = domain.providerName
        sd.itemTypeRaw = domain.itemType.rawValue
        sd.categoryRaw = domain.category.rawValue
        sd.amountValue = domain.amount
        sd.currencyCode = domain.currencyCode
        sd.billingCycleRaw = BillingCycleEncoder.encode(domain.billingCycle)
        sd.startDate = dates.startDate
        sd.nextChargeDate = dates.nextChargeDate
        sd.trialEndDate = dates.trialEndDate
        sd.autoRenew = domain.autoRenew
        sd.endDate = dates.endDate
        sd.chargeReminderRaw = domain.chargeReminder.rawValue
        sd.trialReminderRaw = domain.trialReminder.rawValue
        sd.statusRaw = domain.status.rawValue
        sd.usageStatusRaw = domain.usageStatus.rawValue
        sd.paymentMethodID = domain.paymentMethodID
        sd.note = domain.note
        sd.tagsRaw = TagsEncoder.encode(domain.tags)
        sd.isShared = domain.isShared
        sd.isFamilyPlan = domain.isFamilyPlan
        sd.bundleID = domain.bundleID
        sd.managementURL = domain.managementURL
        sd.updatedAt = domain.updatedAt
        sd.archivedAt = domain.archivedAt
        sd.billingDateEncodingVersion = RecurringItemBillingDateAdapter.canonicalEncodingVersion
        // Existing legacy interpretation policy remains intact after conversion.
    }

    private static func preparedRenewalDecision(_ domain: RecurringItem) throws -> (deadline: Date?, reminderEnabled: Bool) {
        try domain.validateRenewalDecision()
        return (try domain.renewalDecisionDeadline.map(CivilDateStorageCodec().encode), domain.renewalDecisionReminderEnabled)
    }

    private static func decodedBillingDates(_ sd: SDRecurringItem) throws -> RecurringItemBillingDateAdapter.Dates {
        try RecurringItemBillingDateAdapter().decode(
            .init(startDate: sd.startDate, nextChargeDate: sd.nextChargeDate,
                  trialEndDate: sd.trialEndDate, endDate: sd.endDate),
            itemID: sd.id, encodingVersion: sd.billingDateEncodingVersion,
            legacyTimeZoneIdentifier: sd.legacyBillingDateInterpretationTimeZoneIdentifier
        )
    }

    private static func preparedBillingDates(_ domain: RecurringItem) throws -> RecurringItemBillingDateAdapter.Dates {
        try RecurringItemBillingDateAdapter().decode(
            .init(startDate: domain.startDate, nextChargeDate: domain.nextChargeDate,
                  trialEndDate: domain.trialEndDate, endDate: domain.endDate),
            itemID: domain.id, encodingVersion: RecurringItemBillingDateAdapter.canonicalEncodingVersion,
            legacyTimeZoneIdentifier: nil
        )
    }
}

// MARK: - BillingCycle Encoder

/// Encodes BillingCycle to/from a stable string.
/// Uses simple string format: "weekly", "monthly", "custom:30"
enum BillingCycleEncoder {
    enum DecodingError: Error, Equatable {
        case invalidCustomCycle(String)
    }

    static func encode(_ cycle: BillingCycle) -> String {
        switch cycle {
        case .weekly:            "weekly"
        case .monthly:           "monthly"
        case .quarterly:         "quarterly"
        case .semiannual:        "semiannual"
        case .annual:            "annual"
        case .custom(let days):  "custom:\(days)"
        }
    }

    static func decode(_ raw: String) throws -> BillingCycle {
        switch raw {
        case "weekly":      return .weekly
        case "monthly":     return .monthly
        case "quarterly":   return .quarterly
        case "semiannual":  return .semiannual
        case "annual":      return .annual
        default:
            if raw == "custom" || raw.hasPrefix("custom:") {
                guard raw.hasPrefix("custom:"),
                      let days = Int(raw.dropFirst("custom:".count)), days > 0 else {
                    throw DecodingError.invalidCustomCycle(raw)
                }
                return .custom(days: days)
            }
            return .monthly  // Existing policy for unrelated unknown encodings.
        }
    }
}

// MARK: - Tags Encoder

/// Encodes [String] tags to/from a comma-separated string.
/// Simple format — tags must not contain commas.
enum TagsEncoder {

    /// Encodes tags as a comma-separated string.
    /// Strips commas from individual tag values to prevent round-trip corruption.
    static func encode(_ tags: [String]) -> String {
        tags
            .map { $0.replacingOccurrences(of: ",", with: "") }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
    }

    static func decode(_ raw: String) -> [String] {
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }
}
