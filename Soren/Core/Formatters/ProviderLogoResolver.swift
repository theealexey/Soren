import Foundation

// MARK: - Provider Logo Resolver

/// Builds ordered remote fallback URLs for a provider template.
///
/// Placed in Core rather than Domain so that external host strings
/// (`t1.gstatic.com`) never appear in Domain entities.
enum ProviderLogoResolver {

    /// Resolution order:
    /// 1. Explicit service-level source.
    /// 2. Explicitly allowed company/domain-level fallback.
    ///
    /// Returns an empty array when neither source is configured.
    static func logoURLs(for provider: ProviderTemplate) -> [URL] {
        var sources: [URL] = []

        if let serviceSource = provider.serviceLogoSourceURL {
            sources.append(serviceSource)
        }

        if let domain = provider.companyLogoFallbackDomain,
           let companySource = URL(string: "https://\(domain)"),
           !sources.contains(companySource) {
            sources.append(companySource)
        }

        return sources.compactMap(googleFaviconURL(for:))
    }

    private static func googleFaviconURL(for source: URL) -> URL? {
        var components = URLComponents(string: "https://t1.gstatic.com/faviconV2")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "SOCIAL"),
            URLQueryItem(name: "type", value: "FAVICON"),
            URLQueryItem(name: "fallback_opts", value: "TYPE,SIZE,URL"),
            URLQueryItem(name: "url", value: source.absoluteString),
            URLQueryItem(name: "size", value: "256"),
        ]
        return components?.url
    }
}
