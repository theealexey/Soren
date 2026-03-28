import Foundation

// MARK: - Global Providers

extension ProviderCatalog {

    static let global: [ProviderTemplate] = [
        // MARK: Video
        .init(id: "netflix", displayName: "Netflix", aliases: ["нетфликс"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "popular"], managementURL: URL(string: "https://www.netflix.com/account")),

        .init(id: "youtube_premium", displayName: "YouTube Premium", aliases: ["ютуб", "youtube"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "ad-free", "popular"]),

        .init(id: "disney_plus", displayName: "Disney+", aliases: ["дисней"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"]),

        .init(id: "hbo_max", displayName: "Max (HBO)", aliases: ["hbo", "max"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"]),

        .init(id: "apple_tv_plus", displayName: "Apple TV+", aliases: ["apple tv", "эпл тв"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "apple"]),

        .init(id: "amazon_prime_video", displayName: "Amazon Prime Video", aliases: ["амазон", "prime video"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "amazon"]),

        .init(id: "crunchyroll", displayName: "Crunchyroll", aliases: ["кранчиролл", "аниме"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "anime"]),

        .init(id: "mubi", displayName: "MUBI", aliases: ["муби"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "arthouse"]),

        // MARK: Music
        .init(id: "spotify", displayName: "Spotify", aliases: ["спотифай"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "streaming", "popular"]),

        .init(id: "apple_music", displayName: "Apple Music", aliases: ["эпл мьюзик"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "apple"]),

        .init(id: "tidal", displayName: "TIDAL", aliases: ["тайдал"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "hifi"]),

        .init(id: "deezer", displayName: "Deezer", aliases: ["дизер"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"]),

        .init(id: "soundcloud_go", displayName: "SoundCloud Go+", aliases: ["саундклауд"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"]),

        // MARK: Cloud
        .init(id: "icloud", displayName: "iCloud+", aliases: ["айклауд", "icloud"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "storage", "popular"]),

        .init(id: "google_one", displayName: "Google One", aliases: ["гугл один", "google drive"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["google", "storage"]),

        .init(id: "dropbox", displayName: "Dropbox", aliases: ["дропбокс"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["storage"]),

        .init(id: "onedrive", displayName: "Microsoft OneDrive", aliases: ["уандрайв"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["microsoft", "storage"]),

        // MARK: AI Tools
        .init(id: "chatgpt_plus", displayName: "ChatGPT Plus", aliases: ["чатгпт", "openai", "gpt"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "popular"]),

        .init(id: "claude_pro", displayName: "Claude Pro", aliases: ["клод", "anthropic"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai"]),

        .init(id: "midjourney", displayName: "Midjourney", aliases: ["миджорни"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "image"]),

        .init(id: "github_copilot", displayName: "GitHub Copilot", aliases: ["копайлот", "copilot"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"]),

        .init(id: "cursor", displayName: "Cursor", aliases: ["курсор"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"]),

        .init(id: "perplexity", displayName: "Perplexity Pro", aliases: ["перплексити"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "search"]),

        .init(id: "notion_ai", displayName: "Notion AI", aliases: ["ноушен"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "productivity"]),

        // MARK: Productivity
        .init(id: "notion", displayName: "Notion", aliases: ["ноушен"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["notes", "workspace"]),

        .init(id: "figma", displayName: "Figma", aliases: ["фигма"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"]),

        .init(id: "linear", displayName: "Linear", aliases: ["линеар"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["project-management"]),

        .init(id: "slack", displayName: "Slack", aliases: ["слак"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication"]),

        .init(id: "zoom", displayName: "Zoom", aliases: ["зум"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication", "video"]),

        .init(id: "microsoft_365", displayName: "Microsoft 365", aliases: ["office", "office 365", "ms 365"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["office", "microsoft"]),

        .init(id: "1password", displayName: "1Password", aliases: ["ванпассворд"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["security", "passwords"]),

        .init(id: "canva", displayName: "Canva Pro", aliases: ["канва"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"]),

        .init(id: "adobe_cc", displayName: "Adobe Creative Cloud", aliases: ["адоби", "фотошоп", "photoshop"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design", "creative"]),

        // MARK: VPN & Security
        .init(id: "nordvpn", displayName: "NordVPN", aliases: ["норд"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn", "popular"]),

        .init(id: "surfshark", displayName: "Surfshark", aliases: ["серфшарк"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn"]),

        .init(id: "mullvad", displayName: "Mullvad VPN", aliases: ["мулвад"],
              category: .vpn, suggestedCurrencyCode: "EUR", region: .global,
              tags: ["vpn", "privacy"]),

        // MARK: Shopping
        .init(id: "amazon_prime", displayName: "Amazon Prime", aliases: ["амазон прайм"],
              category: .shopping, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery", "amazon"]),

        // MARK: Games
        .init(id: "ps_plus", displayName: "PlayStation Plus", aliases: ["ps plus", "пс плюс", "playstation"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"]),

        .init(id: "xbox_gamepass", displayName: "Xbox Game Pass", aliases: ["геймпас", "game pass"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "microsoft"]),

        .init(id: "nintendo_online", displayName: "Nintendo Switch Online", aliases: ["нинтендо"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"]),

        .init(id: "apple_arcade", displayName: "Apple Arcade", aliases: ["эпл аркейд"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "apple"]),

        // MARK: Health
        .init(id: "strava", displayName: "Strava", aliases: ["страва"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness"]),

        .init(id: "headspace", displayName: "Headspace", aliases: ["хедспейс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["meditation"]),

        .init(id: "apple_fitness_plus", displayName: "Apple Fitness+", aliases: ["фитнес плюс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness", "apple"]),

        // MARK: Education
        .init(id: "duolingo", displayName: "Duolingo Plus", aliases: ["дуолинго"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["language"]),

        .init(id: "coursera", displayName: "Coursera Plus", aliases: ["курсера"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["courses"]),

        // MARK: Books
        .init(id: "kindle_unlimited", displayName: "Kindle Unlimited", aliases: ["киндл"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["books", "amazon"]),

        .init(id: "audible", displayName: "Audible", aliases: ["аудибл", "аудиокниги"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["audiobooks", "amazon"]),

        // MARK: Food
        .init(id: "uber_eats_pass", displayName: "Uber One", aliases: ["убер"],
              category: .food, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery"]),

        // MARK: Creators & Donations
        .init(id: "patreon", displayName: "Patreon", aliases: ["патреон"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"]),

        .init(id: "twitch_sub", displayName: "Twitch Subscriptions", aliases: ["твич", "twitch"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "streaming"]),

        .init(id: "youtube_membership", displayName: "YouTube Memberships", aliases: ["ютуб мемберство"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "youtube"]),

        .init(id: "ko_fi", displayName: "Ko-fi", aliases: ["кофи"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"]),

        .init(id: "buy_me_a_coffee", displayName: "Buy Me a Coffee", aliases: ["бай ми э кофе", "bmac"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"]),

        .init(id: "substack", displayName: "Substack", aliases: ["сабстак"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "newsletter"]),

        .init(id: "onlyfans", displayName: "OnlyFans", aliases: ["онлифанс"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators"]),

        // MARK: Apple Bundles
        .init(id: "apple_one", displayName: "Apple One", aliases: ["эпл ван"],
              category: .cloud, itemType: .ecosystemBundle, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "bundle"]),
    ]
}
