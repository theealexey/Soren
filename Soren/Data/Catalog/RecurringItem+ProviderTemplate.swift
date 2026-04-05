import Foundation

// MARK: - Provider Template Lookup

extension RecurringItem {
    /// Resolves the catalog entry for this item's provider ID.
    /// Returns nil for manually-entered items with no matching catalog provider.
    var providerTemplate: ProviderTemplate? {
        ProviderCatalog.template(forProviderID: providerID)
    }
}
