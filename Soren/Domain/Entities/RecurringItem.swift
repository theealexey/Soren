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

// MARK: - Computed Properties

extension RecurringItem {
    /// Monthly-normalised cost in the item's native currency.
    var monthlyEquivalent: Decimal {
        amount * billingCycle.monthlyMultiplier
    }

    /// Approximate annual cost.
    var annualEquivalent: Decimal {
        monthlyEquivalent * 12
    }

    /// True if next charge is within the given number of days.
    func isDue(within days: Int, from date: Date = .now) -> Bool {
        let threshold = Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
        return nextChargeDate <= threshold && nextChargeDate >= date
    }

    /// True if this is an active trial.
    var isActiveTrial: Bool {
        guard let trialEnd = trialEndDate else { return false }
        return status == .trial && trialEnd > .now
    }

    /// Days until the trial expires. nil if not a trial.
    var daysUntilTrialEnd: Int? {
        guard let trialEnd = trialEndDate, isActiveTrial else { return nil }
        return Calendar.current.dateComponents([.day], from: .now, to: trialEnd).day
    }

    /// Days until next charge. Negative if overdue.
    var daysUntilNextCharge: Int {
        Calendar.current.dateComponents([.day], from: .now, to: nextChargeDate).day ?? 0
    }
}
