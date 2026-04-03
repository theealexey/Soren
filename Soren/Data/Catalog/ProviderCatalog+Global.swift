import Foundation

// MARK: - Global Providers

extension ProviderCatalog {

    static let global: [ProviderTemplate] = [
        // MARK: Video
        .init(id: "netflix", displayName: "Netflix", aliases: ["нетфликс"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "popular"], managementURL: URL(string: "https://www.netflix.com/account"),
              brandColorHex: "#E50914", clearbitDomain: "netflix.com",
              plans: [
                  .init(id: "standard_ads", name: "Standard с рекламой", amount: 7.99, billingCycle: .monthly, features: "1080p, 2 экрана"),
                  .init(id: "standard", name: "Standard", amount: 15.49, billingCycle: .monthly, features: "1080p, 2 экрана, скачивание"),
                  .init(id: "premium", name: "Premium", amount: 22.99, billingCycle: .monthly, features: "4K HDR, 4 экрана"),
              ]),

        .init(id: "youtube_premium", displayName: "YouTube Premium", aliases: ["ютуб", "youtube"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "ad-free", "popular"],
              brandColorHex: "#FF0000", clearbitDomain: "youtube.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 13.99, billingCycle: .monthly),
                  .init(id: "family", name: "Family", amount: 22.99, billingCycle: .monthly, features: "До 5 участников"),
                  .init(id: "student", name: "Student", amount: 7.99, billingCycle: .monthly),
              ]),

        .init(id: "disney_plus", displayName: "Disney+", aliases: ["дисней"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"],
              brandColorHex: "#113CCF", clearbitDomain: "disneyplus.com",
              plans: [
                  .init(id: "standard_ads", name: "Standard с рекламой", amount: 9.99, billingCycle: .monthly),
                  .init(id: "standard", name: "Standard", amount: 15.99, billingCycle: .monthly, features: "Скачивание, без рекламы"),
                  .init(id: "premium", name: "Premium", amount: 19.99, billingCycle: .monthly, features: "4K HDR, Dolby Atmos, 4 экрана"),
              ]),

        .init(id: "hbo_max", displayName: "Max (HBO)", aliases: ["hbo", "max"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"],
              brandColorHex: "#002BE7", clearbitDomain: "max.com"),

        .init(id: "apple_tv_plus", displayName: "Apple TV+", aliases: ["apple tv", "эпл тв"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "apple"],
              brandColorHex: "#000000", clearbitDomain: "apple.com"),

        .init(id: "amazon_prime_video", displayName: "Amazon Prime Video", aliases: ["амазон", "prime video"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "amazon"],
              brandColorHex: "#00A8E1", clearbitDomain: "primevideo.com"),

        .init(id: "crunchyroll", displayName: "Crunchyroll", aliases: ["кранчиролл", "аниме"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "anime"],
              brandColorHex: "#F47521", clearbitDomain: "crunchyroll.com"),

        .init(id: "mubi", displayName: "MUBI", aliases: ["муби"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "arthouse"],
              brandColorHex: "#001B38", clearbitDomain: "mubi.com"),

        // MARK: Music
        .init(id: "spotify", displayName: "Spotify", aliases: ["спотифай"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "streaming", "popular"],
              brandColorHex: "#1DB954", clearbitDomain: "spotify.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 11.99, billingCycle: .monthly),
                  .init(id: "duo", name: "Duo", amount: 16.99, billingCycle: .monthly, features: "2 аккаунта"),
                  .init(id: "family", name: "Family", amount: 19.99, billingCycle: .monthly, features: "До 6 участников"),
                  .init(id: "student", name: "Student", amount: 5.99, billingCycle: .monthly),
              ]),

        .init(id: "apple_music", displayName: "Apple Music", aliases: ["эпл мьюзик"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "apple"],
              brandColorHex: "#FC3C44", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 10.99, billingCycle: .monthly),
                  .init(id: "family", name: "Family", amount: 16.99, billingCycle: .monthly, features: "До 6 участников"),
                  .init(id: "student", name: "Student", amount: 5.99, billingCycle: .monthly),
              ]),

        .init(id: "tidal", displayName: "TIDAL", aliases: ["тайдал"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "hifi"],
              brandColorHex: "#000000", clearbitDomain: "tidal.com"),

        .init(id: "deezer", displayName: "Deezer", aliases: ["дизер"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#A238FF", clearbitDomain: "deezer.com"),

        .init(id: "soundcloud_go", displayName: "SoundCloud Go+", aliases: ["саундклауд"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#FF5500", clearbitDomain: "soundcloud.com"),

        .init(id: "qobuz", displayName: "Qobuz", aliases: ["кобуз"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "hifi", "lossless"],
              brandColorHex: "#000000", clearbitDomain: "qobuz.com",
              plans: [
                  .init(id: "studio", name: "Studio", amount: 12.99, billingCycle: .monthly, features: "Hi-Res 24-bit, без рекламы"),
                  .init(id: "studio_annual", name: "Studio (год)", amount: 129.99, billingCycle: .annual, features: "Hi-Res 24-bit, без рекламы"),
              ]),

        // MARK: Cloud
        .init(id: "icloud", displayName: "iCloud+", aliases: ["айклауд", "icloud"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "storage", "popular"],
              brandColorHex: "#3693F5", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "50gb", name: "50 ГБ", amount: 0.99, billingCycle: .monthly),
                  .init(id: "200gb", name: "200 ГБ", amount: 2.99, billingCycle: .monthly),
                  .init(id: "2tb", name: "2 ТБ", amount: 9.99, billingCycle: .monthly),
                  .init(id: "6tb", name: "6 ТБ", amount: 29.99, billingCycle: .monthly),
                  .init(id: "12tb", name: "12 ТБ", amount: 59.99, billingCycle: .monthly),
              ]),

        .init(id: "google_one", displayName: "Google One", aliases: ["гугл один", "google drive"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["google", "storage"],
              brandColorHex: "#4285F4", clearbitDomain: "google.com"),

        .init(id: "dropbox", displayName: "Dropbox", aliases: ["дропбокс"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["storage"],
              brandColorHex: "#0061FF", clearbitDomain: "dropbox.com"),

        .init(id: "onedrive", displayName: "Microsoft OneDrive", aliases: ["уандрайв"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["microsoft", "storage"],
              brandColorHex: "#0078D4", clearbitDomain: "microsoft.com"),

        // MARK: AI Tools
        .init(id: "chatgpt_plus", displayName: "ChatGPT Plus", aliases: ["чатгпт", "openai", "gpt"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "popular"],
              brandColorHex: "#10A37F", clearbitDomain: "openai.com",
              plans: [
                  .init(id: "plus", name: "Plus", amount: 20, billingCycle: .monthly),
                  .init(id: "team", name: "Team", amount: 25, billingCycle: .monthly, features: "Расширенные лимиты"),
                  .init(id: "pro", name: "Pro", amount: 200, billingCycle: .monthly, features: "Безлимитный доступ"),
              ]),

        .init(id: "claude_pro", displayName: "Claude Pro", aliases: ["клод", "anthropic"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai"],
              brandColorHex: "#D97757", clearbitDomain: "anthropic.com",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 20, billingCycle: .monthly),
                  .init(id: "max", name: "Max", amount: 100, billingCycle: .monthly, features: "Расширенные лимиты, приоритет"),
              ]),

        .init(id: "midjourney", displayName: "Midjourney", aliases: ["миджорни"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "image"],
              brandColorHex: "#000000", clearbitDomain: "midjourney.com"),

        .init(id: "github_copilot", displayName: "GitHub Copilot", aliases: ["копайлот", "copilot"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", clearbitDomain: "github.com"),

        .init(id: "cursor", displayName: "Cursor", aliases: ["курсор"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", clearbitDomain: "cursor.com"),

        .init(id: "perplexity", displayName: "Perplexity Pro", aliases: ["перплексити"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "search"],
              brandColorHex: "#20808D", clearbitDomain: "perplexity.ai"),

        .init(id: "notion_ai", displayName: "Notion AI", aliases: ["ноушен"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "productivity"],
              brandColorHex: "#000000", clearbitDomain: "notion.so"),

        // MARK: Productivity
        .init(id: "notion", displayName: "Notion", aliases: ["ноушен"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["notes", "workspace"],
              brandColorHex: "#000000", clearbitDomain: "notion.so"),

        .init(id: "figma", displayName: "Figma", aliases: ["фигма"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"],
              brandColorHex: "#F24E1E", clearbitDomain: "figma.com"),

        .init(id: "linear", displayName: "Linear", aliases: ["линеар"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["project-management"],
              brandColorHex: "#5E6AD2", clearbitDomain: "linear.app"),

        .init(id: "slack", displayName: "Slack", aliases: ["слак"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication"],
              brandColorHex: "#4A154B", clearbitDomain: "slack.com"),

        .init(id: "zoom", displayName: "Zoom", aliases: ["зум"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication", "video"],
              brandColorHex: "#0B5CFF", clearbitDomain: "zoom.us"),

        .init(id: "microsoft_365", displayName: "Microsoft 365", aliases: ["office", "office 365", "ms 365"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["office", "microsoft"],
              brandColorHex: "#D83B01", clearbitDomain: "microsoft.com"),

        .init(id: "1password", displayName: "1Password", aliases: ["ванпассворд"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["security", "passwords"],
              brandColorHex: "#0572EC", clearbitDomain: "1password.com"),

        .init(id: "canva", displayName: "Canva Pro", aliases: ["канва"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"],
              brandColorHex: "#00C4CC", clearbitDomain: "canva.com"),

        .init(id: "adobe_cc", displayName: "Adobe Creative Cloud", aliases: ["адоби", "фотошоп", "photoshop"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design", "creative"],
              brandColorHex: "#FF0000", clearbitDomain: "adobe.com"),

        // MARK: VPN & Security
        .init(id: "nordvpn", displayName: "NordVPN", aliases: ["норд"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn", "popular"],
              brandColorHex: "#4687FF", clearbitDomain: "nordvpn.com"),

        .init(id: "surfshark", displayName: "Surfshark", aliases: ["серфшарк"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn"],
              brandColorHex: "#178BF1", clearbitDomain: "surfshark.com"),

        .init(id: "mullvad", displayName: "Mullvad VPN", aliases: ["мулвад"],
              category: .vpn, suggestedCurrencyCode: "EUR", region: .global,
              tags: ["vpn", "privacy"],
              brandColorHex: "#294D73", clearbitDomain: "mullvad.net"),

        // MARK: Shopping
        .init(id: "amazon_prime", displayName: "Amazon Prime", aliases: ["амазон прайм"],
              category: .shopping, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery", "amazon"],
              brandColorHex: "#FF9900", clearbitDomain: "amazon.com"),

        // MARK: Games
        .init(id: "ps_plus", displayName: "PlayStation Plus", aliases: ["ps plus", "пс плюс", "playstation"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#003087", clearbitDomain: "playstation.com"),

        .init(id: "xbox_gamepass", displayName: "Xbox Game Pass", aliases: ["геймпас", "game pass"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "microsoft"],
              brandColorHex: "#107C10", clearbitDomain: "xbox.com"),

        .init(id: "nintendo_online", displayName: "Nintendo Switch Online", aliases: ["нинтендо"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#E60012", clearbitDomain: "nintendo.com"),

        .init(id: "apple_arcade", displayName: "Apple Arcade", aliases: ["эпл аркейд"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "apple"],
              brandColorHex: "#0070C9", clearbitDomain: "apple.com"),

        // MARK: Health
        .init(id: "strava", displayName: "Strava", aliases: ["страва"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness"],
              brandColorHex: "#FC4C02", clearbitDomain: "strava.com"),

        .init(id: "headspace", displayName: "Headspace", aliases: ["хедспейс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["meditation"],
              brandColorHex: "#F47D31", clearbitDomain: "headspace.com"),

        .init(id: "apple_fitness_plus", displayName: "Apple Fitness+", aliases: ["фитнес плюс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness", "apple"],
              brandColorHex: "#97D608", clearbitDomain: "apple.com"),

        // MARK: Education
        .init(id: "duolingo", displayName: "Duolingo Plus", aliases: ["дуолинго"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["language"],
              brandColorHex: "#58CC02", clearbitDomain: "duolingo.com"),

        .init(id: "coursera", displayName: "Coursera Plus", aliases: ["курсера"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["courses"],
              brandColorHex: "#0056D2", clearbitDomain: "coursera.org"),

        // MARK: Books
        .init(id: "kindle_unlimited", displayName: "Kindle Unlimited", aliases: ["киндл"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["books", "amazon"],
              brandColorHex: "#FF9900", clearbitDomain: "amazon.com"),

        .init(id: "audible", displayName: "Audible", aliases: ["аудибл", "аудиокниги"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["audiobooks", "amazon"],
              brandColorHex: "#F8991D", clearbitDomain: "audible.com"),

        // MARK: Food
        .init(id: "uber_eats_pass", displayName: "Uber One", aliases: ["убер"],
              category: .food, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery"],
              brandColorHex: "#000000", clearbitDomain: "uber.com"),

        // MARK: Creators & Donations
        .init(id: "patreon", displayName: "Patreon", aliases: ["патреон"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#FF424D", clearbitDomain: "patreon.com"),

        .init(id: "twitch_sub", displayName: "Twitch Subscriptions", aliases: ["твич", "twitch"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "streaming"],
              brandColorHex: "#9146FF", clearbitDomain: "twitch.tv"),

        .init(id: "youtube_membership", displayName: "YouTube Memberships", aliases: ["ютуб мемберство"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "youtube"],
              brandColorHex: "#FF0000", clearbitDomain: "youtube.com"),

        .init(id: "ko_fi", displayName: "Ko-fi", aliases: ["кофи"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#13C3FF", clearbitDomain: "ko-fi.com"),

        .init(id: "buy_me_a_coffee", displayName: "Buy Me a Coffee", aliases: ["бай ми э кофе", "bmac"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#FFDD00", clearbitDomain: "buymeacoffee.com"),

        .init(id: "substack", displayName: "Substack", aliases: ["сабстак"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "newsletter"],
              brandColorHex: "#FF6719", clearbitDomain: "substack.com"),

        .init(id: "onlyfans", displayName: "OnlyFans", aliases: ["онлифанс"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators"],
              brandColorHex: "#00AFF0", clearbitDomain: "onlyfans.com"),

        // MARK: Apple Bundles
        .init(id: "apple_one", displayName: "Apple One", aliases: ["эпл ван"],
              category: .cloud, itemType: .ecosystemBundle, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "bundle"],
              brandColorHex: "#000000", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 19.95, billingCycle: .monthly, features: "Music, TV+, Arcade, iCloud+ 50 ГБ"),
                  .init(id: "family", name: "Family", amount: 25.95, billingCycle: .monthly, features: "До 6 чел., iCloud+ 200 ГБ"),
                  .init(id: "premier", name: "Premier", amount: 37.95, billingCycle: .monthly, features: "Все + News+, Fitness+, iCloud+ 2 ТБ"),
              ]),
    ]
}
