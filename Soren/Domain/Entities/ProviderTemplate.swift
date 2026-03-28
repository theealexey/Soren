import Foundation

/// A pre-defined service template from the provider catalog.
/// When a user picks a provider, these values pre-fill the AddItem form.
struct ProviderTemplate: Identifiable, Hashable, Sendable {
    let id: String            // stable string ID, e.g. "yandex_plus", "netflix"
    var displayName: String
    var aliases: [String]     // alternative names for search matching
    var category: ItemCategory
    var itemType: ItemType
    var suggestedCycle: BillingCycle
    var suggestedCurrencyCode: String
    var region: Region
    var tags: [String]
    /// URL to open the subscription management page.
    var managementURL: URL?
    /// SF Symbol or asset name for the icon.
    var iconAssetName: String?
    /// Available pricing tiers. Empty means no predefined plans.
    var plans: [PlanTier]

    /// Whether this provider has predefined plan tiers.
    var hasPlanTiers: Bool { !plans.isEmpty }

    init(
        id: String,
        displayName: String,
        aliases: [String] = [],
        category: ItemCategory,
        itemType: ItemType = .subscription,
        suggestedCycle: BillingCycle = .monthly,
        suggestedCurrencyCode: String = "RUB",
        region: Region = .global,
        tags: [String] = [],
        managementURL: URL? = nil,
        iconAssetName: String? = nil,
        plans: [PlanTier] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.aliases = aliases
        self.category = category
        self.itemType = itemType
        self.suggestedCycle = suggestedCycle
        self.suggestedCurrencyCode = suggestedCurrencyCode
        self.region = region
        self.tags = tags
        self.managementURL = managementURL
        self.iconAssetName = iconAssetName
        self.plans = plans
    }
}

extension ProviderTemplate {
    enum Region: String, Codable, Sendable {
        case global
        case russia
        case europe
        case us
    }

    /// True if this template matches a given search query.
    /// Empty query matches all providers (used to show full catalog).
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        return displayName.lowercased().contains(q)
            || aliases.contains { $0.lowercased().contains(q) }
            || id.lowercased().contains(q)
    }
}
