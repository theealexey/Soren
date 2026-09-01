import SwiftData
import Foundation

// MARK: - SwiftData Model: Recurring Item

/// Persistent storage model for a recurring payment item.
/// This is the SwiftData @Model counterpart to the Domain's `RecurringItem` struct.
///
/// Design decisions:
/// - `id` has `.unique` to prevent duplicates on iCloud sync or import
/// - Stored as class (required by @Model), but never leaked outside Data layer
/// - Enums stored as rawValue strings for forward compatibility
/// - Relationship to payments uses `.cascade` delete — payments are meaningless without item
@Model
final class SDRecurringItem {

    // MARK: - Identity

    @Attribute(.unique) var id: UUID
    var title: String
    var providerID: String?
    var providerName: String

    // MARK: - Classification

    var itemTypeRaw: String
    var categoryRaw: String

    // MARK: - Financial

    var amountValue: Decimal
    var currencyCode: String
    var billingCycleRaw: String   // encoded as JSON string for custom(days:) support

    // MARK: - Dates

    var startDate: Date
    var nextChargeDate: Date
    var trialEndDate: Date?

    /// `nil` means the row has no proven canonical civil-date provenance.
    var billingDateEncodingVersion: Int? = nil

    /// Reserved for a future bootstrap decision about ambiguous legacy dates.
    var legacyBillingDateInterpretationTimeZoneIdentifier: String? = nil

    // MARK: - Lifecycle

    /// Stored as `Bool?` so that adding this column is a lightweight migration:
    /// existing rows receive `nil`, which the mapper treats as `true` (legacy default).
    /// New or re-saved rows always carry an explicit `true` or `false`.
    var autoRenew: Bool?

    /// Non-nil only for finite (autoRenew == false) subscriptions.
    /// Always `nil` when autoRenew is true — enforced at the use-case save boundary.
    var endDate: Date?

    /// `ChargeReminderOption.rawValue`. Lightweight migration: existing rows receive
    /// `nil` (stored as optional), which the mapper treats as `.threeDaysBefore` to
    /// preserve the behaviour users had before per-subscription timing was introduced.
    var chargeReminderRaw: String?

    /// `TrialReminderOption.rawValue`. Optional column for lightweight migration:
    /// existing rows receive `nil`, which the mapper treats as `.never` (safe default —
    /// trial notifications are opt-in).
    var trialReminderRaw: String?

    // MARK: - State

    var statusRaw: String
    var usageStatusRaw: String

    // MARK: - Payment

    var paymentMethodID: UUID?

    // MARK: - Organisation

    var note: String
    var tagsRaw: String           // JSON-encoded [String]
    var isShared: Bool
    var isFamilyPlan: Bool
    var bundleID: UUID?
    var managementURL: URL?

    // MARK: - Audit

    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    // MARK: - Relationships

    @Relationship(deleteRule: .cascade, inverse: \SDPaymentRecord.item)
    var payments: [SDPaymentRecord]

    @Relationship(deleteRule: .nullify, inverse: \SDReminderRule.item)
    var reminders: [SDReminderRule]

    // MARK: - Init

    init(
        id: UUID,
        title: String,
        providerID: String?,
        providerName: String,
        itemTypeRaw: String,
        categoryRaw: String,
        amountValue: Decimal,
        currencyCode: String,
        billingCycleRaw: String,
        startDate: Date,
        nextChargeDate: Date,
        trialEndDate: Date?,
        autoRenew: Bool? = nil,
        endDate: Date? = nil,
        chargeReminderRaw: String? = nil,
        trialReminderRaw: String? = nil,
        statusRaw: String,
        usageStatusRaw: String,
        paymentMethodID: UUID?,
        note: String,
        tagsRaw: String,
        isShared: Bool,
        isFamilyPlan: Bool,
        bundleID: UUID?,
        managementURL: URL?,
        createdAt: Date,
        updatedAt: Date,
        archivedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.providerID = providerID
        self.providerName = providerName
        self.itemTypeRaw = itemTypeRaw
        self.categoryRaw = categoryRaw
        self.amountValue = amountValue
        self.currencyCode = currencyCode
        self.billingCycleRaw = billingCycleRaw
        self.startDate = startDate
        self.nextChargeDate = nextChargeDate
        self.trialEndDate = trialEndDate
        self.autoRenew = autoRenew
        self.endDate = endDate
        self.chargeReminderRaw = chargeReminderRaw
        self.trialReminderRaw = trialReminderRaw
        self.statusRaw = statusRaw
        self.usageStatusRaw = usageStatusRaw
        self.paymentMethodID = paymentMethodID
        self.note = note
        self.tagsRaw = tagsRaw
        self.isShared = isShared
        self.isFamilyPlan = isFamilyPlan
        self.bundleID = bundleID
        self.managementURL = managementURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.payments = []
        self.reminders = []
    }
}
