import Foundation

// MARK: - Provider Catalog

/// In-memory catalog of known services and providers.
/// Grouped by region and category for fast lookup.
/// This is the single source of truth for the Quick Add flow.
enum ProviderCatalog {

    private static let bakedTileArtworkProviderIDs: Set<String> = [
        "qobuz",
        "tidal",
    ]

    private static let glyphArtworkProviderIDs: Set<String> = [
        "adobe_cc",
        "apple_one",
        "boosty",
        "docplus",
        "donationalerts",
        "github_copilot",
        "kindle_unlimited",
        "mail_cloud",
        "meta_verified",
        "okko",
        "onedrive",
        "premier",
        "sber_prime",
        "skillbox",
        "sponsr",
        "vk_music",
        "vk_play",
        "yota",
    ]

    static func applyingBundledLogoPresentations(
        to providers: [ProviderTemplate]
    ) -> [ProviderTemplate] {
        providers.map { provider in
            var provider = provider
            if bakedTileArtworkProviderIDs.contains(provider.id) {
                provider.logoPresentation = .bakedTile
            } else if glyphArtworkProviderIDs.contains(provider.id) {
                provider.logoPresentation = .adaptiveGlyph
            } else {
                provider.logoPresentation = .appIcon
            }
            return provider
        }
    }

    /// All providers across all regions, including legacy templates kept for persisted items.
    static let all: [ProviderTemplate] = (global + russia).sorted { $0.displayName < $1.displayName }

    /// Providers available when creating a new subscription.
    static let selectable: [ProviderTemplate] = all.filter(\.isSelectable)

    /// O(1) lookup index — built once from `all` at module load time.
    /// Uses last-wins deduplication so a copy-paste ID collision never crashes.
    private static let _index: [String: ProviderTemplate] =
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })

    /// Resolves a catalog template from a persisted `RecurringItem.providerID`.
    static func template(forProviderID id: String?) -> ProviderTemplate? {
        guard let id else { return nil }
        return _index[id]
    }
}
