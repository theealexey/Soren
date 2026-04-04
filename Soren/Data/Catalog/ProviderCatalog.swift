import Foundation

// MARK: - Provider Catalog

/// In-memory catalog of known services and providers.
/// Grouped by region and category for fast lookup.
/// This is the single source of truth for the Quick Add flow.
enum ProviderCatalog {

    /// All providers across all regions, sorted alphabetically.
    static let all: [ProviderTemplate] = (global + russia).sorted { $0.displayName < $1.displayName }

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
