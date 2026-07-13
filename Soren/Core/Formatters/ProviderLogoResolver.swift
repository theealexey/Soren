import Foundation

// MARK: - Provider Logo Resolver

/// Builds the remote fallback URL for a provider template.
///
/// Placed in Core rather than Domain so that external host strings
/// (`t1.gstatic.com`) never appear in Domain entities.
enum ProviderLogoResolver {

    /// Returns the verified remote fallback URL for the given provider.
    /// Returns an empty array when `clearbitDomain` is nil (no remote logo available).
    static func logoURLs(for provider: ProviderTemplate) -> [URL] {
        guard let domain = provider.clearbitDomain else { return [] }

        let googlePath = "https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON"
            + "&fallback_opts=TYPE,SIZE,URL&url=https://\(domain)&size=256"
        return URL(string: googlePath).map { [$0] } ?? []
    }
}
