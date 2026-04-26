import Foundation

// MARK: - Provider Logo Resolver

/// Builds the ordered list of remote logo URLs for a provider template.
///
/// Priority: Clearbit (best quality) → Google favicon (reliable fallback).
/// `LogoLoader` attempts them in order and returns the first successful response.
///
/// Placed in Core rather than Domain so that external host strings
/// (`logo.clearbit.com`, `t1.gstatic.com`) never appear in Domain entities.
enum ProviderLogoResolver {

    /// Returns an ordered list of logo URLs to try for the given provider.
    /// Returns an empty array when `clearbitDomain` is nil (no remote logo available).
    static func logoURLs(for provider: ProviderTemplate) -> [URL] {
        guard let domain = provider.clearbitDomain else { return [] }

        var urls: [URL] = []

        // Clearbit — highest quality, 256 pt square PNG
        if let clearbit = URL(string: "https://logo.clearbit.com/\(domain)?size=256") {
            urls.append(clearbit)
        }

        // Google favicon — always available, no auth required
        let googlePath = "https://t1.gstatic.com/faviconV2?client=SOCIAL&type=FAVICON"
            + "&fallback_opts=TYPE,SIZE,URL&url=https://\(domain)&size=256"
        if let google = URL(string: googlePath) {
            urls.append(google)
        }

        return urls
    }
}
