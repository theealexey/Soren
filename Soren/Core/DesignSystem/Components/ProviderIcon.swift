import SwiftUI

// MARK: - Provider Icon

/// Displays a service provider icon with consistent sizing.
///
/// Resolution priority:
/// 1. Real logo from Clearbit CDN (async, cached by URLSession)
/// 2. Asset catalog image named `provider_{id}` (bundled override)
/// 3. Letter-mark with brand color gradient (generated, instant)
/// 4. SF Symbol by category (fallback for manual entries)
struct ProviderIcon: View {
    private let content: Content
    let size: Size

    // MARK: - Init (Provider-based)

    /// Creates an icon from a provider template.
    /// Tries Clearbit logo first, falls back to letter-mark.
    init(provider: ProviderTemplate, size: Size = .medium) {
        let assetName = "provider_\(provider.id)"
        if UIImage(named: assetName) != nil {
            self.content = .asset(assetName, provider, size)
        } else if let url = provider.logoURL {
            self.content = .remoteLogo(url, provider, size)
        } else if let hex = provider.brandColorHex {
            self.content = .letterMark(provider.letterMark, Color(hex: hex))
        } else {
            self.content = .symbol(provider.category.systemIconName, provider.category.color)
        }
        self.size = size
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
        case .remoteLogo(let url, let provider, let iconSize):
            RemoteLogoIcon(url: url, provider: provider, size: iconSize)

        case .asset(let name, _, _):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size.frame, height: size.frame)
                .clipShape(RoundedRectangle(cornerRadius: size.radius))

        case .letterMark(let letters, let color):
            letterMarkView(letters: letters, color: color)

        case .symbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size.frame, height: size.frame)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
        }
    }

    // MARK: - Letter Mark

    private func letterMarkView(letters: String, color: Color) -> some View {
        Text(letters)
            .font(.system(size: size.letterSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
    }
}

// MARK: - Remote Logo

/// Loads a logo from Clearbit asynchronously.
/// Shows a letter-mark placeholder during loading; fades in the logo on success.
private struct RemoteLogoIcon: View {
    let url: URL
    let provider: ProviderTemplate
    let size: ProviderIcon.Size

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: size.frame * 0.72, height: size.frame * 0.72)
                    .frame(width: size.frame, height: size.frame)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: size.radius))
                    .overlay(
                        RoundedRectangle(cornerRadius: size.radius)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                    )
                    .transition(.opacity)

            case .failure:
                // Clearbit failed — show letter-mark permanently
                letterMark

            default:
                // Loading — show letter-mark as placeholder
                letterMark
            }
        }
    }

    private var letterMark: some View {
        Text(provider.letterMark)
            .font(.system(size: size.letterSize, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(
                (Color(hex: provider.brandColorHex ?? "#888888")).gradient,
                in: RoundedRectangle(cornerRadius: size.radius)
            )
    }
}

// MARK: - Content

extension ProviderIcon {
    private enum Content {
        case remoteLogo(URL, ProviderTemplate, Size)
        case asset(String, ProviderTemplate, Size)
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

#Preview("Clearbit Logos") {
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
