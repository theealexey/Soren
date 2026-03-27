import Foundation

// MARK: - Provider Catalog

/// In-memory catalog of known services and providers.
/// Grouped by region and category for fast lookup.
/// This is the single source of truth for the Quick Add flow.
enum ProviderCatalog {

    /// All providers across all regions, sorted alphabetically.
    static let all: [ProviderTemplate] = (global + russia).sorted { $0.displayName < $1.displayName }
}
