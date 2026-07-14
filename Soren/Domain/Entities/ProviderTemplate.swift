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
    /// Whether this provider may be selected when creating a new subscription.
    /// Legacy templates remain resolvable by stable ID even when this is false.
    var isSelectable: Bool
    /// URL to open the subscription management page.
    var managementURL: URL?
    /// SF Symbol or asset name for the icon.
    var iconAssetName: String?
    /// Direct service-specific image URL used as the first remote fallback.
    /// This must return image data rather than an HTML service page.
    var serviceLogoSourceURL: URL?
    /// Hex brand color (e.g. "#E50914" for Netflix). Used for letter-mark icons.
    var brandColorHex: String?
    /// Explicitly allowed company/domain-level favicon fallback
    /// (e.g. "netflix.com", "yandex.ru").
    /// Pass to `ProviderLogoResolver.logoURLs(for:)` to obtain fetch URLs.
    var companyLogoFallbackDomain: String?
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
        isSelectable: Bool = true,
        managementURL: URL? = nil,
        iconAssetName: String? = nil,
        serviceLogoSourceURL: URL? = nil,
        brandColorHex: String? = nil,
        companyLogoFallbackDomain: String? = nil,
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
        self.isSelectable = isSelectable
        self.managementURL = managementURL
        self.iconAssetName = iconAssetName
        self.serviceLogoSourceURL = serviceLogoSourceURL
        self.brandColorHex = brandColorHex
        self.companyLogoFallbackDomain = companyLogoFallbackDomain
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

    /// Short letter-mark for icon display (e.g. "N" for Netflix, "VK" for VK Музыка).
    var letterMark: String {
        let name = displayName

        // Short all-caps brands (VK, МТС, HBO, IVI, etc.) — show as-is up to 3 chars
        if name.count <= 3, name == name.uppercased(), name.first?.isLetter == true {
            return name
        }

        let words = name.split(separator: " ").map(String.init)

        // Single word → first letter
        if words.count == 1 {
            return String(name.prefix(1)).uppercased()
        }

        // 2-letter abbreviation at start (VK, МТС, HBO, etc.)
        if let first = words.first, first.count <= 3, first == first.uppercased(),
           first.first?.isLetter == true {
            return first
        }

        // Multi-word → first letters of first 2 letter-starting words (skip parentheticals)
        let letterWords = words.filter { $0.first?.isLetter == true }
        let initials = letterWords.prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.uppercased()
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
