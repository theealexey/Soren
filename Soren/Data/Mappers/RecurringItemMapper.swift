import Foundation

// MARK: - Recurring Item Mapper

/// Converts between the SwiftData storage model (SDRecurringItem)
/// and the Domain entity (RecurringItem).
///
/// All conversion logic lives here — both @Model and Domain struct remain clean.
enum RecurringItemMapper {

    // MARK: - SD → Domain

    static func toDomain(_ sd: SDRecurringItem) -> RecurringItem {
        RecurringItem(
            id: sd.id,
            title: sd.title,
            providerID: sd.providerID,
            providerName: sd.providerName,
            itemType: ItemType(rawValue: sd.itemTypeRaw) ?? .otherRecurring,
            category: ItemCategory(rawValue: sd.categoryRaw) ?? .other,
            amount: sd.amountValue,
            currencyCode: sd.currencyCode,
            billingCycle: BillingCycleEncoder.decode(sd.billingCycleRaw),
            startDate: sd.startDate,
            nextChargeDate: sd.nextChargeDate,
            trialEndDate: sd.trialEndDate,
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
    }

    // MARK: - Domain → SD (new)

    static func toSD(_ domain: RecurringItem) -> SDRecurringItem {
        SDRecurringItem(
            id: domain.id,
            title: domain.title,
            providerID: domain.providerID,
            providerName: domain.providerName,
            itemTypeRaw: domain.itemType.rawValue,
            categoryRaw: domain.category.rawValue,
            amountValue: domain.amount,
            currencyCode: domain.currencyCode,
            billingCycleRaw: BillingCycleEncoder.encode(domain.billingCycle),
            startDate: domain.startDate,
            nextChargeDate: domain.nextChargeDate,
            trialEndDate: domain.trialEndDate,
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
    }

    // MARK: - Domain → SD (update existing)

    /// Updates an existing SDRecurringItem in-place from a domain entity.
    /// Used by the Repository's `update` method — avoids deleting/reinserting.
    static func update(_ sd: SDRecurringItem, from domain: RecurringItem) {
        sd.title = domain.title
        sd.providerID = domain.providerID
        sd.providerName = domain.providerName
        sd.itemTypeRaw = domain.itemType.rawValue
        sd.categoryRaw = domain.category.rawValue
        sd.amountValue = domain.amount
        sd.currencyCode = domain.currencyCode
        sd.billingCycleRaw = BillingCycleEncoder.encode(domain.billingCycle)
        sd.startDate = domain.startDate
        sd.nextChargeDate = domain.nextChargeDate
        sd.trialEndDate = domain.trialEndDate
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
    }
}

// MARK: - BillingCycle Encoder

/// Encodes BillingCycle to/from a stable string.
/// Uses simple string format: "weekly", "monthly", "custom:30"
enum BillingCycleEncoder {

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

    static func decode(_ raw: String) -> BillingCycle {
        switch raw {
        case "weekly":      .weekly
        case "monthly":     .monthly
        case "quarterly":   .quarterly
        case "semiannual":  .semiannual
        case "annual":      .annual
        default:
            if raw.hasPrefix("custom:"),
               let daysStr = raw.split(separator: ":").last,
               let days = Int(daysStr), days > 0 {
                .custom(days: days)
            } else {
                .monthly  // safe fallback
            }
        }
    }
}

// MARK: - Tags Encoder

/// Encodes [String] tags to/from a comma-separated string.
/// Simple format — tags must not contain commas.
enum TagsEncoder {

    static func encode(_ tags: [String]) -> String {
        tags.joined(separator: ",")
    }

    static func decode(_ raw: String) -> [String] {
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }
}
