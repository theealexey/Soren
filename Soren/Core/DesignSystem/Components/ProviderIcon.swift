import SwiftUI
import UIKit

// MARK: - Logo Loader

/// Loads provider logos from a prioritised list of URLs.
/// Caches in memory (NSCache) and on disk (URLCache on URLSession).
/// Coalesces concurrent requests for the same provider so scrolling does not
/// start duplicate network work or cancel the shared load.
///
/// Implemented as an `actor` so that NSCache mutations are serialised and
/// UIImage values are safely passed to @MainActor callers under Swift 6.
actor LogoLoader {

    typealias DataLoader = @Sendable (URL) async throws -> (Data, URLResponse)

    static let shared = LogoLoader()

    private let loadData: DataLoader
    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [NSURL: Task<UIImage?, Never>] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 100 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        let session = URLSession(configuration: config)
        self.loadData = { url in
            try await session.data(from: url)
        }
        memory.countLimit = 300
    }

    init(loadData: @escaping DataLoader) {
        self.loadData = loadData
        memory.countLimit = 300
    }

    func image(for urls: [URL]) async -> UIImage? {
        guard let key = urls.first else { return nil }
        let cacheKey = key as NSURL

        if let cached = memory.object(forKey: cacheKey) {
            return cached
        }
        if let existing = inFlight[cacheKey] {
            return await existing.value
        }

        let loadData = self.loadData
        let task = Task<UIImage?, Never> {
            for url in urls {
                if let image = await Self.fetch(url, using: loadData) {
                    return image
                }
            }
            return nil
        }
        inFlight[cacheKey] = task

        let image = await task.value
        inFlight[cacheKey] = nil

        if let image {
            memory.setObject(image, forKey: cacheKey)
        }
        return image
    }

    private nonisolated static func fetch(_ url: URL, using loadData: DataLoader) async -> UIImage? {
        guard let (data, response) = try? await loadData(url),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              http.mimeType?.lowercased().hasPrefix("image/") == true,
              !data.isEmpty,
              let image = UIImage(data: data) else { return nil }
        return image
    }
}

// MARK: - Provider Icon

/// Displays a service provider icon with consistent sizing.
///
/// Resolution priority:
/// 1. Bundled asset — image named `iconAssetName` or `provider_{id}` in Assets.xcassets
/// 2. Service logo  — explicit service-level remote source
/// 3. Company logo  — explicitly allowed domain-level fallback
/// 4. Letter-mark   — instant, shown while remote loads or on failure
/// 5. SF Symbol     — category icon, for manual entries without a provider
struct ProviderIcon: View {
    private let content: Content
    let size: Size

    enum Resolution: Equatable {
        case asset(String)
        case remote([URL])
        case letterMark
        case symbol
    }

    // MARK: - Init (Provider-based)

    init(provider: ProviderTemplate, size: Size = .medium) {
        switch Self.resolution(for: provider) {
        case .asset(let assetName):
            self.content = .asset(assetName)
        case .remote(let logoURLs):
            self.content = .remoteLogo(logoURLs, provider)
        case .letterMark:
            let hex = provider.brandColorHex ?? "#888888"
            self.content = .letterMark(provider.letterMark, Color(hex: hex))
        case .symbol:
            self.content = .symbol(provider.category.systemIconName, provider.category.color)
        }
        self.size = size
    }

    static func resolution(for provider: ProviderTemplate) -> Resolution {
        if let assetName = bundledAssetName(for: provider) {
            return .asset(assetName)
        }

        let logoURLs = ProviderLogoResolver.logoURLs(for: provider)
        if !logoURLs.isEmpty {
            return .remote(logoURLs)
        }

        return provider.brandColorHex == nil ? .symbol : .letterMark
    }

    private static func bundledAssetName(for provider: ProviderTemplate) -> String? {
        if let custom = provider.iconAssetName, UIImage(named: custom) != nil { return custom }
        let standard = "provider_\(provider.id)"
        return UIImage(named: standard) != nil ? standard : nil
    }

    // MARK: - Init (SF Symbol / Category)

    init(systemName: String, color: Color = ColorTokens.accent, size: Size = .medium) {
        self.content = .symbol(systemName, color)
        self.size = size
    }

    init(category: ItemCategory, size: Size = .medium) {
        self.content = .symbol(category.systemIconName, category.color)
        self.size = size
    }

    // MARK: - Body

    var body: some View {
        switch content {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size.frame * 0.72, height: size.frame * 0.72)
                .frame(width: size.frame, height: size.frame)
                .background(Color.white, in: RoundedRectangle(cornerRadius: size.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: size.radius)
                        .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                )

        case .remoteLogo(let urls, let provider):
            RemoteLogoIcon(urls: urls, provider: provider, size: size)

        case .letterMark(let letters, let color):
            letterMarkView(letters: letters, color: color)

        case .symbol(let name, let color):
            symbolView(name: name, color: color)
        }
    }

    private func letterMarkView(letters: String, color: Color) -> some View {
        Text(letters)
            .font(.system(size: size.letterSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
    }

    private func symbolView(name: String, color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
    }
}

// MARK: - Remote Logo Icon

/// Shows a letter-mark immediately, then fades in the real logo when loaded.
/// Uses LogoLoader for coalesced memory + disk-cached remote fallback loading.
private struct RemoteLogoIcon: View {
    let urls: [URL]
    let provider: ProviderTemplate
    let size: ProviderIcon.Size

    @State private var loaded: UIImage? = nil

    var body: some View {
        ZStack {
            // Letter-mark is always rendered underneath — instant, no flicker
            letterMark

            if let image = loaded {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.frame * 0.72, height: size.frame * 0.72)
                    .frame(width: size.frame, height: size.frame)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: size.radius))
                    .overlay(
                        RoundedRectangle(cornerRadius: size.radius)
                            .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            }
        }
        .task(id: urls.first) {
            loaded = nil
            loaded = await LogoLoader.shared.image(for: urls)
        }
    }

    private var letterMark: some View {
        Text(provider.letterMark)
            .font(.system(size: size.letterSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(
                Color(hex: provider.brandColorHex ?? "#888888").gradient,
                in: RoundedRectangle(cornerRadius: size.radius)
            )
    }
}

// MARK: - Content

extension ProviderIcon {
    private enum Content {
        case asset(String)
        case remoteLogo([URL], ProviderTemplate)
        case letterMark(String, Color)
        case symbol(String, Color)
    }
}

// MARK: - Size

extension ProviderIcon {
    enum Size {
        case small   // 28pt — compact lists
        case medium  // 40pt — standard list rows
        case large   // 56pt — detail screen hero, catalog cards

        var frame: CGFloat {
            switch self { case .small: 28; case .medium: 40; case .large: 56 }
        }

        var iconSize: CGFloat {
            switch self { case .small: 12; case .medium: 16; case .large: 22 }
        }

        var letterSize: CGFloat {
            switch self { case .small: 13; case .medium: 17; case .large: 24 }
        }

        var radius: CGFloat {
            switch self {
            case .small:  CornerRadius.small
            case .medium: CornerRadius.medium
            case .large:  CornerRadius.medium
            }
        }
    }
}

// MARK: - Preview

#Preview("Logo Grid") {
    let providers = [
        ProviderCatalog.global.first { $0.id == "netflix" }!,
        ProviderCatalog.global.first { $0.id == "spotify" }!,
        ProviderCatalog.global.first { $0.id == "youtube_premium" }!,
        ProviderCatalog.global.first { $0.id == "disney_plus" }!,
        ProviderCatalog.global.first { $0.id == "chatgpt_plus" }!,
        ProviderCatalog.global.first { $0.id == "claude_pro" }!,
        ProviderCatalog.global.first { $0.id == "slack" }!,
        ProviderCatalog.global.first { $0.id == "figma" }!,
        ProviderCatalog.russia.first { $0.id == "yandex_plus" }!,
        ProviderCatalog.russia.first { $0.id == "sber_prime" }!,
        ProviderCatalog.russia.first { $0.id == "kinopoisk" }!,
        ProviderCatalog.russia.first { $0.id == "vk_music" }!,
    ]

    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Spacing.md) {
            ForEach(providers, id: \.id) { provider in
                VStack(spacing: Spacing.xs) {
                    ProviderIcon(provider: provider, size: .large)
                    Text(provider.displayName)
                        .font(Typography.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding(Spacing.lg)
    }
    .background(ColorTokens.background)
}
