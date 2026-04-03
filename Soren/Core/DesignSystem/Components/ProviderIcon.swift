import SwiftUI

// MARK: - Provider Icon

/// Displays a service provider icon with consistent sizing.
///
/// Resolution priority:
/// 1. Bundled asset image named `iconAssetName` or `provider_{id}` in Assets.xcassets
/// 2. Letter-mark with brand-color gradient (generated, instant, no network)
/// 3. SF Symbol by category (fallback for manual entries without a provider)
struct ProviderIcon: View {
    private let content: Content
    let size: Size

    // MARK: - Init (Provider-based)

    /// Creates an icon from a provider template.
    /// Bundled asset takes priority; otherwise falls to letter-mark or category symbol.
    init(provider: ProviderTemplate, size: Size = .medium) {
        if let assetName = Self.bundledAssetName(for: provider) {
            self.content = .asset(assetName)
        } else if let hex = provider.brandColorHex {
            self.content = .letterMark(provider.letterMark, Color(hex: hex))
        } else {
            self.content = .symbol(provider.category.systemIconName, provider.category.color)
        }
        self.size = size
    }

    /// Checks `Assets.xcassets` for a bundled image: `iconAssetName` or `provider_{id}`.
    private static func bundledAssetName(for provider: ProviderTemplate) -> String? {
        if let custom = provider.iconAssetName, UIImage(named: custom) != nil {
            return custom
        }
        let standard = "provider_\(provider.id)"
        return UIImage(named: standard) != nil ? standard : nil
    }

    // MARK: - Init (SF Symbol fallback)

    /// Creates an icon from an SF Symbol — for manual entries without a provider.
    init(systemName: String, color: Color = ColorTokens.accent, size: Size = .medium) {
        self.content = .symbol(systemName, color)
        self.size = size
    }

    // MARK: - Init (Category fallback)

    /// Creates an icon from a category — shows the category SF Symbol with its color.
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
                .scaledToFill()
                .frame(width: size.frame, height: size.frame)
                .clipShape(RoundedRectangle(cornerRadius: size.radius))

        case .letterMark(let letters, let color):
            Text(letters)
                .font(.system(size: size.letterSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: size.frame, height: size.frame)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))

        case .symbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size.frame, height: size.frame)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
        }
    }
}

// MARK: - Content

extension ProviderIcon {
    private enum Content {
        case asset(String)
        case letterMark(String, Color)
        case symbol(String, Color)
    }
}

// MARK: - Size

extension ProviderIcon {
    enum Size {
        /// 28pt frame — compact lists, secondary display.
        case small
        /// 40pt frame — standard list rows.
        case medium
        /// 56pt frame — detail screen hero, catalog cards.
        case large

        var frame: CGFloat {
            switch self {
            case .small:  28
            case .medium: 40
            case .large:  56
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small:  12
            case .medium: 16
            case .large:  22
            }
        }

        var letterSize: CGFloat {
            switch self {
            case .small:  13
            case .medium: 17
            case .large:  24
            }
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

#Preview("Letter-mark Grid") {
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
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible()),
        ], spacing: Spacing.md) {
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

#Preview("Sizes + Fallback") {
    let netflix = ProviderCatalog.global.first { $0.id == "netflix" }!

    HStack(spacing: Spacing.md) {
        ProviderIcon(provider: netflix, size: .small)
        ProviderIcon(provider: netflix, size: .medium)
        ProviderIcon(provider: netflix, size: .large)
        ProviderIcon(systemName: "star.fill", color: .purple, size: .medium)
        ProviderIcon(category: .video, size: .medium)
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
