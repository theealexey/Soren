import Foundation

/// The primary domain entity representing any recurring payment.
///
/// Deliberately uses value semantics (struct) so it can be passed across
/// actors and stored in SwiftUI state without concurrency concerns.
/// Persistence (SwiftData) uses a separate @Model type mapped via a Repository.
struct RecurringItem: Identifiable, Hashable, Sendable {

    // MARK: - Identity

    let id: UUID
    var title: String

    // MARK: - Provider

    /// Identifier into the provider catalog. nil if manually added.
    var providerID: String?
    var providerName: String

    // MARK: - Classification

    var itemType: ItemType
    var category: ItemCategory

    // MARK: - Financial

    var amount: Decimal
    var currencyCode: String   // ISO 4217, e.g. "RUB", "USD", "EUR"
    var billingCycle: BillingCycle

    // MARK: - Dates

    var startDate: Date
    var nextChargeDate: Date
    var trialEndDate: Date?

    // MARK: - Lifecycle

    /// When `true` (default) the subscription renews indefinitely until cancelled.
    /// When `false`, the subscription terminates on `endDate` (which must be non-nil).
    var autoRenew: Bool

    /// The date after which no further charges occur.
    /// Required when `autoRenew == false`; always `nil` when `autoRenew == true` (enforced at save boundary).
    var endDate: Date?

    // MARK: - Notifications

    /// Per-subscription charge reminder timing chosen by the user.
    var chargeReminder: ChargeReminderOption

    /// Per-subscription trial-end reminder timing chosen by the user.
    /// Defaults to `.never` — users opt in when they actually want a trial warning.
    var trialReminder: TrialReminderOption

    // MARK: - State

    var status: ItemStatus
    var usageStatus: UsageStatus

    // MARK: - Payment

    var paymentMethodID: UUID?

    // MARK: - Organisation

    var note: String
    var tags: [String]
    var isShared: Bool
    var isFamilyPlan: Bool
    var bundleID: UUID?         // parent bundle this item belongs to

    // MARK: - Links

    var managementURL: URL?

    // MARK: - Audit

    let createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?

    // MARK: - Init

    init(
        id: UUID = UUID(),
        title: String,
        providerID: String? = nil,
        providerName: String = "",
        itemType: ItemType = .subscription,
        category: ItemCategory = .other,
        amount: Decimal,
        currencyCode: String = "RUB",
        billingCycle: BillingCycle = .monthly,
        startDate: Date = .now,
        nextChargeDate: Date,
        trialEndDate: Date? = nil,
        autoRenew: Bool = true,
        endDate: Date? = nil,
        chargeReminder: ChargeReminderOption = .threeDaysBefore,
        trialReminder: TrialReminderOption = .never,
        status: ItemStatus = .active,
        usageStatus: UsageStatus = .unknown,
        paymentMethodID: UUID? = nil,
        note: String = "",
        tags: [String] = [],
        isShared: Bool = false,
        isFamilyPlan: Bool = false,
        bundleID: UUID? = nil,
        managementURL: URL? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.providerID = providerID
        self.providerName = providerName.isEmpty ? title : providerName
        self.itemType = itemType
        self.category = category
        self.amount = amount
        self.currencyCode = currencyCode
        self.billingCycle = billingCycle
        self.startDate = startDate
        self.nextChargeDate = nextChargeDate
        self.trialEndDate = trialEndDate
        self.autoRenew = autoRenew
        self.endDate = endDate
        self.chargeReminder = chargeReminder
        self.trialReminder = trialReminder
        self.status = status
        self.usageStatus = usageStatus
        self.paymentMethodID = paymentMethodID
        self.note = note
        self.tags = tags
        self.isShared = isShared
        self.isFamilyPlan = isFamilyPlan
        self.bundleID = bundleID
        self.managementURL = managementURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }
}

// MARK: - Explicit canonical civil-day API

extension RecurringItem {
    func validateCanonicalBillingDates() throws {
        let fields: [(RecurringItemBillingDateValidationError.Field, Date?)] = [
            (.startDate, startDate), (.nextChargeDate, nextChargeDate),
            (.trialEndDate, trialEndDate), (.endDate, endDate)
        ]
        for (field, date) in fields {
            guard let date else { continue }
            do { _ = try BillingCivilDay.civilDate(fromCanonicalDate: date) }
            catch {
                throw RecurringItemBillingDateValidationError(itemID: id, field: field, underlying: error)
            }
        }
    }

    func isActiveTrial(on today: CivilDate) throws -> Bool {
        guard status == .trial, let trialEndDate else { return false }
        return try BillingCivilDay.civilDate(fromCanonicalDate: trialEndDate) > today
    }

    func daysUntilTrialEnd(from today: CivilDate) throws -> Int? {
        guard try isActiveTrial(on: today), let trialEndDate else { return nil }
        return try BillingCivilDay.days(from: today, to: BillingCivilDay.civilDate(fromCanonicalDate: trialEndDate))
    }

    func renewalDisplay(relativeTo today: CivilDate) throws -> RenewalDisplay {
        guard !autoRenew, let endDate else { return .renewing }
        let days = try BillingCivilDay.days(from: today, to: BillingCivilDay.civilDate(fromCanonicalDate: endDate))
        if days < 0 { return .expired }
        if days <= 30 { return .endingSoon(daysLeft: days) }
        return .renewing
    }

    func isExpired(on today: CivilDate) throws -> Bool {
        if case .expired = try renewalDisplay(relativeTo: today) { return true }
        return false
    }

    func daysUntilNextCharge(from today: CivilDate) throws -> Int {
        try BillingCivilDay.days(from: today, to: BillingCivilDay.civilDate(fromCanonicalDate: nextChargeDate))
    }

    func isDue(within days: Int, from today: CivilDate) throws -> Bool {
        let difference = try daysUntilNextCharge(from: today)
        return difference >= 0 && difference <= days
    }

    /// Deterministic equivalent of the existing display-only rollover helper.
    /// Schedule projection remains owned by RecurringScheduleProjector.
    func effectiveNextChargeDate(relativeTo today: CivilDate) throws -> Date {
        _ = try BillingCivilDay.civilDate(fromCanonicalDate: nextChargeDate)
        let boundary = try BillingCivilDay.canonicalDate(for: today)
        switch status {
        case .paused, .cancelled, .archived: return nextChargeDate
        default: break
        }
        guard autoRenew, nextChargeDate < boundary else { return nextChargeDate }
        var candidate = nextChargeDate
        var iterations = 0
        while candidate < boundary, iterations < 1_000 {
            candidate = billingCycle.nextDate(after: candidate, calendar: BillingCivilDay.calendar)
            iterations += 1
        }
        return candidate
    }
}

// MARK: - Computed Properties

extension RecurringItem {
    /// Monthly-normalised cost in the item's native currency.
    var monthlyEquivalent: Decimal {
        get throws { try annualEquivalent / 12 }
    }

    /// Annualized recurring cost, independent of occurrences in a particular year.
    var annualEquivalent: Decimal {
        get throws { try billingCycle.annualEquivalent(for: amount) }
    }

    /// Display-layer classification of how this item's lifecycle will end.
    /// Derived solely from `autoRenew`, `endDate`, and the current date.
    /// Never mutates persisted state.
    enum RenewalDisplay: Equatable {
        case renewing                  // auto-renewal active; no end in sight
        case endingSoon(daysLeft: Int) // finite subscription expiring within 30 days
        case expired                   // finite subscription whose endDate has passed
    }

}
