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
                  .init(id: "individual_annual", name: "Individual (год)", amount: 159.99, billingCycle: .annual, features: "Экономия ~$8"),
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
                  .init(id: "premium_annual", name: "Premium (год)", amount: 189.99, billingCycle: .annual, features: "4K HDR, Dolby Atmos, 4 экрана"),
              ]),

        .init(id: "hbo_max", displayName: "Max (HBO)", aliases: ["hbo", "max"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"],
              brandColorHex: "#002BE7", clearbitDomain: "max.com",
              plans: [
                  .init(id: "with_ads", name: "С рекламой", amount: 9.99, billingCycle: .monthly, features: "FHD, 2 экрана"),
                  .init(id: "with_ads_annual", name: "С рекламой (год)", amount: 109.99, billingCycle: .annual, features: "FHD, 2 экрана"),
                  .init(id: "ad_free", name: "Без рекламы", amount: 15.99, billingCycle: .monthly, features: "FHD, 2 экрана"),
                  .init(id: "ad_free_annual", name: "Без рекламы (год)", amount: 184.99, billingCycle: .annual, features: "FHD, 2 экрана"),
                  .init(id: "ultimate", name: "Ultimate", amount: 19.99, billingCycle: .monthly, features: "4K, 4 экрана, Dolby Atmos"),
                  .init(id: "ultimate_annual", name: "Ultimate (год)", amount: 229.99, billingCycle: .annual, features: "4K, 4 экрана, Dolby Atmos"),
              ]),

        .init(id: "apple_tv_plus", displayName: "Apple TV+", aliases: ["apple tv", "эпл тв"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "apple"],
              brandColorHex: "#000000", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 9.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 99.99, billingCycle: .annual, features: "Экономия ~$20"),
              ]),

        .init(id: "amazon_prime_video", displayName: "Amazon Prime Video", aliases: ["амазон", "prime video"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "amazon"],
              brandColorHex: "#00A8E1", clearbitDomain: "primevideo.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 8.99, billingCycle: .monthly, features: "Только видео"),
              ]),

        .init(id: "crunchyroll", displayName: "Crunchyroll", aliases: ["кранчиролл", "аниме"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "anime"],
              brandColorHex: "#F47521", clearbitDomain: "crunchyroll.com",
              plans: [
                  .init(id: "fan", name: "Fan", amount: 7.99, billingCycle: .monthly, features: "1 поток, без рекламы"),
                  .init(id: "mega_fan", name: "Mega Fan", amount: 9.99, billingCycle: .monthly, features: "4 потока, скачивание"),
                  .init(id: "ultimate_fan", name: "Ultimate Fan", amount: 14.99, billingCycle: .monthly, features: "Все функции + Funimation"),
              ]),

        .init(id: "mubi", displayName: "MUBI", aliases: ["муби"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "arthouse"],
              brandColorHex: "#001B38", clearbitDomain: "mubi.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 14.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 107.88, billingCycle: .annual, features: "Экономия ~$72"),
              ]),

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
              brandColorHex: "#000000", clearbitDomain: "tidal.com",
              plans: [
                  .init(id: "hifi", name: "HiFi", amount: 10.99, billingCycle: .monthly, features: "Lossless FLAC"),
                  .init(id: "hifi_plus", name: "HiFi+", amount: 19.99, billingCycle: .monthly, features: "HiRes, Dolby Atmos, Sony 360"),
                  .init(id: "family", name: "Family HiFi", amount: 16.99, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "deezer", displayName: "Deezer", aliases: ["дизер"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#A238FF", clearbitDomain: "deezer.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 10.99, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", amount: 107.99, billingCycle: .annual, features: "Экономия ~$24"),
                  .init(id: "duo", name: "Duo", amount: 14.99, billingCycle: .monthly, features: "2 аккаунта"),
                  .init(id: "family", name: "Family", amount: 17.99, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "soundcloud_go", displayName: "SoundCloud Go+", aliases: ["саундклауд"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#FF5500", clearbitDomain: "soundcloud.com",
              plans: [
                  .init(id: "go", name: "Go", amount: 5.99, billingCycle: .monthly, features: "Без рекламы"),
                  .init(id: "go_plus", name: "Go+", amount: 9.99, billingCycle: .monthly, features: "Оффлайн, Hi-Q аудио"),
              ]),

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
              brandColorHex: "#4285F4", clearbitDomain: "google.com",
              plans: [
                  .init(id: "100gb", name: "100 ГБ", amount: 1.99, billingCycle: .monthly),
                  .init(id: "100gb_annual", name: "100 ГБ (год)", amount: 19.99, billingCycle: .annual, features: "Экономия ~$4"),
                  .init(id: "200gb", name: "200 ГБ", amount: 2.99, billingCycle: .monthly),
                  .init(id: "200gb_annual", name: "200 ГБ (год)", amount: 29.99, billingCycle: .annual, features: "Экономия ~$6"),
                  .init(id: "2tb", name: "2 ТБ", amount: 9.99, billingCycle: .monthly),
                  .init(id: "2tb_annual", name: "2 ТБ (год)", amount: 99.99, billingCycle: .annual, features: "Экономия ~$20"),
                  .init(id: "5tb", name: "5 ТБ", amount: 24.99, billingCycle: .monthly),
                  .init(id: "10tb", name: "10 ТБ", amount: 49.99, billingCycle: .monthly),
              ]),

        .init(id: "dropbox", displayName: "Dropbox", aliases: ["дропбокс"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["storage"],
              brandColorHex: "#0061FF", clearbitDomain: "dropbox.com",
              plans: [
                  .init(id: "plus", name: "Plus", amount: 11.99, billingCycle: .monthly, features: "2 ТБ, 1 пользователь"),
                  .init(id: "plus_annual", name: "Plus (год)", amount: 119.88, billingCycle: .annual, features: "2 ТБ, 1 пользователь"),
                  .init(id: "professional", name: "Professional", amount: 19.99, billingCycle: .monthly, features: "3 ТБ, eSign, расширенный поиск"),
              ]),

        .init(id: "onedrive", displayName: "Microsoft OneDrive", aliases: ["уандрайв"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["microsoft", "storage"],
              brandColorHex: "#0078D4", clearbitDomain: "microsoft.com",
              plans: [
                  .init(id: "100gb", name: "100 ГБ", amount: 1.99, billingCycle: .monthly),
                  .init(id: "m365_personal", name: "Microsoft 365 Personal", amount: 6.99, billingCycle: .monthly, features: "1 ТБ + Office-приложения"),
                  .init(id: "m365_family", name: "Microsoft 365 Family", amount: 9.99, billingCycle: .monthly, features: "До 6 чел., 1 ТБ каждому"),
              ]),

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
              brandColorHex: "#000000", clearbitDomain: "midjourney.com",
              plans: [
                  .init(id: "basic", name: "Basic", amount: 10, billingCycle: .monthly, features: "~200 изображений/мес"),
                  .init(id: "standard", name: "Standard", amount: 30, billingCycle: .monthly, features: "15 ч. GPU, безлимит (relax)"),
                  .init(id: "pro", name: "Pro", amount: 60, billingCycle: .monthly, features: "30 ч. GPU, stealth mode"),
                  .init(id: "mega", name: "Mega", amount: 120, billingCycle: .monthly, features: "60 ч. GPU"),
              ]),

        .init(id: "github_copilot", displayName: "GitHub Copilot", aliases: ["копайлот", "copilot"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", clearbitDomain: "github.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 10, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", amount: 100, billingCycle: .annual),
                  .init(id: "business", name: "Business", amount: 19, billingCycle: .monthly, features: "Управление командой, политики"),
              ]),

        .init(id: "cursor", displayName: "Cursor", aliases: ["курсор"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", clearbitDomain: "cursor.com",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 20, billingCycle: .monthly, features: "500 быстрых запросов/мес"),
                  .init(id: "business", name: "Business", amount: 40, billingCycle: .monthly, features: "Privacy mode, SSO, аудит"),
              ]),

        .init(id: "perplexity", displayName: "Perplexity Pro", aliases: ["перплексити"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "search"],
              brandColorHex: "#20808D", clearbitDomain: "perplexity.ai",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 20, billingCycle: .monthly, features: "GPT-4o, Claude, безлимит поиска"),
              ]),

        .init(id: "notion_ai", displayName: "Notion AI", aliases: ["ноушен"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "productivity"],
              brandColorHex: "#000000", clearbitDomain: "notion.so",
              plans: [
                  .init(id: "ai_addon", name: "AI Add-on", amount: 10, billingCycle: .monthly, features: "На одного участника"),
              ]),

        // MARK: Productivity
        .init(id: "notion", displayName: "Notion", aliases: ["ноушен"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["notes", "workspace"],
              brandColorHex: "#000000", clearbitDomain: "notion.so",
              plans: [
                  .init(id: "plus", name: "Plus", amount: 10, billingCycle: .monthly, features: "Безлимитные страницы и блоки"),
                  .init(id: "business", name: "Business", amount: 18, billingCycle: .monthly, features: "SAML SSO, экспорт PDF"),
              ]),

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
              brandColorHex: "#4A154B", clearbitDomain: "slack.com",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 8.75, billingCycle: .monthly, features: "Полная история, голосовые каналы"),
                  .init(id: "business_plus", name: "Business+", amount: 15, billingCycle: .monthly, features: "SAML SSO, 24/7 поддержка"),
              ]),

        .init(id: "zoom", displayName: "Zoom", aliases: ["зум"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication", "video"],
              brandColorHex: "#0B5CFF", clearbitDomain: "zoom.us",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 14.99, billingCycle: .monthly, features: "30 ч. встречи, 1 ГБ облако"),
                  .init(id: "business", name: "Business", amount: 21.99, billingCycle: .monthly, features: "До 300 участников, транскрипция"),
              ]),

        .init(id: "microsoft_365", displayName: "Microsoft 365", aliases: ["office", "office 365", "ms 365"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["office", "microsoft"],
              brandColorHex: "#D83B01", clearbitDomain: "microsoft.com",
              plans: [
                  .init(id: "personal", name: "Personal", amount: 6.99, billingCycle: .monthly, features: "1 ТБ, Office для 1 чел."),
                  .init(id: "personal_annual", name: "Personal (год)", amount: 99.99, billingCycle: .annual, features: "1 ТБ, Office для 1 чел."),
                  .init(id: "family", name: "Family", amount: 9.99, billingCycle: .monthly, features: "До 6 чел., 1 ТБ каждому"),
                  .init(id: "family_annual", name: "Family (год)", amount: 129.99, billingCycle: .annual, features: "До 6 чел., 1 ТБ каждому"),
              ]),

        .init(id: "1password", displayName: "1Password", aliases: ["ванпассворд"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["security", "passwords"],
              brandColorHex: "#0572EC", clearbitDomain: "1password.com",
              plans: [
                  .init(id: "individual", name: "Individual", amount: 2.99, billingCycle: .monthly),
                  .init(id: "families", name: "Families", amount: 4.99, billingCycle: .monthly, features: "До 5 участников"),
              ]),

        .init(id: "canva", displayName: "Canva Pro", aliases: ["канва"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"],
              brandColorHex: "#00C4CC", clearbitDomain: "canva.com",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 12.99, billingCycle: .monthly, features: "100 ГБ, 420K шаблонов, бренд-кит"),
                  .init(id: "teams", name: "Teams", amount: 14.99, billingCycle: .monthly, features: "На участника, совместный бренд-кит"),
              ]),

        .init(id: "adobe_cc", displayName: "Adobe Creative Cloud", aliases: ["адоби", "фотошоп", "photoshop"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design", "creative"],
              brandColorHex: "#FF0000", clearbitDomain: "adobe.com",
              plans: [
                  .init(id: "photography", name: "Photography", amount: 9.99, billingCycle: .monthly, features: "Lightroom + Photoshop, 20 ГБ"),
                  .init(id: "all_apps", name: "All Apps", amount: 54.99, billingCycle: .monthly, features: "Все 20+ приложений, 100 ГБ"),
              ]),

        .init(id: "telegram_premium", displayName: "Telegram Premium",
              aliases: ["телеграм", "telegram"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["messaging", "communication"],
              brandColorHex: "#2CA5E0", clearbitDomain: "telegram.org",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 4.99, billingCycle: .monthly,
                        features: "Файлы до 4 ГБ, без рекламы, Premium-стикеры"),
                  .init(id: "annual", name: "Annual", amount: 29.99, billingCycle: .annual,
                        features: "~$2.50/мес"),
              ]),

        // MARK: VPN & Security
        .init(id: "nordvpn", displayName: "NordVPN", aliases: ["норд"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn", "popular"],
              brandColorHex: "#4687FF", clearbitDomain: "nordvpn.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 13.99, billingCycle: .monthly, features: "6 устройств"),
                  .init(id: "annual", name: "Annual", amount: 59.88, billingCycle: .annual, features: "~$4.99/мес"),
              ]),

        .init(id: "surfshark", displayName: "Surfshark", aliases: ["серфшарк"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn"],
              brandColorHex: "#178BF1", clearbitDomain: "surfshark.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 15.45, billingCycle: .monthly, features: "Безлимитные устройства"),
                  .init(id: "annual", name: "Annual", amount: 47.88, billingCycle: .annual, features: "~$3.99/мес"),
              ]),

        .init(id: "mullvad", displayName: "Mullvad VPN", aliases: ["мулвад"],
              category: .vpn, suggestedCurrencyCode: "EUR", region: .global,
              tags: ["vpn", "privacy"],
              brandColorHex: "#294D73", clearbitDomain: "mullvad.net",
              plans: [
                  .init(id: "standard", name: "Standard", amount: 5, billingCycle: .monthly, features: "Без аккаунта, анонимно"),
              ]),

        // MARK: Shopping
        .init(id: "amazon_prime", displayName: "Amazon Prime", aliases: ["амазон прайм"],
              category: .shopping, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery", "amazon"],
              brandColorHex: "#FF9900", clearbitDomain: "amazon.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 14.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 139, billingCycle: .annual, features: "Экономия ~$41"),
              ]),

        // MARK: Games
        .init(id: "ps_plus", displayName: "PlayStation Plus", aliases: ["ps plus", "пс плюс", "playstation"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#003087", clearbitDomain: "playstation.com",
              plans: [
                  .init(id: "essential", name: "Essential", amount: 9.99, billingCycle: .monthly, features: "2 игры/мес, онлайн мультиплеер"),
                  .init(id: "essential_annual", name: "Essential (год)", amount: 79.99, billingCycle: .annual, features: "2 игры/мес, онлайн мультиплеер"),
                  .init(id: "extra", name: "Extra", amount: 14.99, billingCycle: .monthly, features: "Каталог 400+ игр"),
                  .init(id: "extra_annual", name: "Extra (год)", amount: 134.99, billingCycle: .annual, features: "Каталог 400+ игр"),
                  .init(id: "premium", name: "Premium", amount: 17.99, billingCycle: .monthly, features: "Классика PS1–PS4, стриминг"),
                  .init(id: "premium_annual", name: "Premium (год)", amount: 159.99, billingCycle: .annual, features: "Классика PS1–PS4, стриминг"),
              ]),

        .init(id: "xbox_gamepass", displayName: "Xbox Game Pass", aliases: ["геймпас", "game pass"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "microsoft"],
              brandColorHex: "#107C10", clearbitDomain: "xbox.com",
              plans: [
                  .init(id: "core", name: "Core", amount: 9.99, billingCycle: .monthly, features: "Онлайн + 25 классических игр"),
                  .init(id: "standard", name: "Standard", amount: 14.99, billingCycle: .monthly, features: "Каталог PC + Console"),
                  .init(id: "ultimate", name: "Ultimate", amount: 19.99, billingCycle: .monthly, features: "PC + Console + EA Play + Cloud"),
              ]),

        .init(id: "nintendo_online", displayName: "Nintendo Switch Online", aliases: ["нинтендо"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#E60012", clearbitDomain: "nintendo.com",
              plans: [
                  .init(id: "individual_monthly", name: "Individual", amount: 3.99, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", amount: 19.99, billingCycle: .annual),
                  .init(id: "family_annual", name: "Family (год)", amount: 34.99, billingCycle: .annual, features: "До 8 аккаунтов"),
              ]),

        .init(id: "apple_arcade", displayName: "Apple Arcade", aliases: ["эпл аркейд"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "apple"],
              brandColorHex: "#0070C9", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 6.99, billingCycle: .monthly, features: "200+ игр, до 6 чел."),
                  .init(id: "annual", name: "Annual", amount: 49.99, billingCycle: .annual, features: "200+ игр, до 6 чел., экономия ~$34"),
              ]),

        // MARK: Health
        .init(id: "strava", displayName: "Strava", aliases: ["страва"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness"],
              brandColorHex: "#FC4C02", clearbitDomain: "strava.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 11.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 79.99, billingCycle: .annual, features: "Экономия ~$64"),
              ]),

        .init(id: "headspace", displayName: "Headspace", aliases: ["хедспейс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["meditation"],
              brandColorHex: "#F47D31", clearbitDomain: "headspace.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 12.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 69.99, billingCycle: .annual, features: "Экономия ~$86"),
              ]),

        .init(id: "apple_fitness_plus", displayName: "Apple Fitness+", aliases: ["фитнес плюс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness", "apple"],
              brandColorHex: "#97D608", clearbitDomain: "apple.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 9.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", amount: 79.99, billingCycle: .annual, features: "Экономия ~$40"),
              ]),

        // MARK: Education
        .init(id: "duolingo", displayName: "Duolingo Plus", aliases: ["дуолинго"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["language"],
              brandColorHex: "#58CC02", clearbitDomain: "duolingo.com",
              plans: [
                  .init(id: "super_monthly", name: "Super", amount: 6.99, billingCycle: .monthly, features: "Без рекламы, безлимитные жизни"),
                  .init(id: "super_annual", name: "Super (год)", amount: 79.99, billingCycle: .annual),
                  .init(id: "family", name: "Family", amount: 119.99, billingCycle: .annual, features: "До 6 участников"),
              ]),

        .init(id: "coursera", displayName: "Coursera Plus", aliases: ["курсера"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["courses"],
              brandColorHex: "#0056D2", clearbitDomain: "coursera.org",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 59, billingCycle: .monthly, features: "Все курсы и сертификаты"),
                  .init(id: "annual", name: "Annual", amount: 399, billingCycle: .annual, features: "Экономия ~$309"),
              ]),

        // MARK: Books
        .init(id: "kindle_unlimited", displayName: "Kindle Unlimited", aliases: ["киндл"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["books", "amazon"],
              brandColorHex: "#FF9900", clearbitDomain: "amazon.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 11.99, billingCycle: .monthly, features: "1M+ книг и журналов"),
              ]),

        .init(id: "audible", displayName: "Audible", aliases: ["аудибл", "аудиокниги"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["audiobooks", "amazon"],
              brandColorHex: "#F8991D", clearbitDomain: "audible.com",
              plans: [
                  .init(id: "plus", name: "Plus", amount: 7.95, billingCycle: .monthly, features: "Безлимитный каталог Plus"),
                  .init(id: "premium_plus", name: "Premium Plus", amount: 14.95, billingCycle: .monthly, features: "1 кредит/мес + каталог Plus"),
              ]),

        // MARK: Food
        .init(id: "uber_eats_pass", displayName: "Uber One", aliases: ["убер"],
              category: .food, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery"],
              brandColorHex: "#000000", clearbitDomain: "uber.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 9.99, billingCycle: .monthly, features: "Без комиссии доставки"),
                  .init(id: "annual", name: "Annual", amount: 99, billingCycle: .annual, features: "Экономия ~$21"),
              ]),

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

        // MARK: Social & Creator Platforms

        .init(id: "meta_verified", displayName: "Meta Verified",
              aliases: ["instagram", "facebook", "meta", "verified",
                        "инстаграм", "фейсбук", "мета"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["social", "creator", "verified"],
              managementURL: URL(string: "https://www.meta.com/verified"),
              brandColorHex: "#0866FF", clearbitDomain: "meta.com",
              plans: [
                  // US reference prices; actual price varies by region and platform.
                  .init(id: "standard", name: "Standard", amount: 14.99, billingCycle: .monthly,
                        features: "Verified badge, поддержка аккаунта"),
                  .init(id: "plus", name: "Plus", amount: 29.99, billingCycle: .monthly,
                        features: "Standard + продвижение профиля"),
                  .init(id: "premium", name: "Premium", amount: 59.99, billingCycle: .monthly,
                        features: "Plus + Stars, эксклюзивные стикеры"),
                  .init(id: "max", name: "Max", amount: 299, billingCycle: .monthly,
                        features: "Полный пакет монетизации"),
              ]),

        .init(id: "x_premium", displayName: "X Premium",
              aliases: ["x", "twitter", "twitter blue", "твиттер", "твиттер блю", "premium+"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["social", "creator", "twitter"],
              managementURL: URL(string: "https://x.com/settings/premium"),
              brandColorHex: "#000000", clearbitDomain: "x.com",
              plans: [
                  // US reference prices at x.com/i/premium.
                  .init(id: "basic_monthly", name: "Basic", amount: 3, billingCycle: .monthly),
                  .init(id: "basic_annual", name: "Basic (год)", amount: 32, billingCycle: .annual,
                        features: "~$2.67/мес"),
                  .init(id: "premium_monthly", name: "Premium", amount: 8, billingCycle: .monthly,
                        features: "Синяя галочка, расширенные посты"),
                  .init(id: "premium_annual", name: "Premium (год)", amount: 84, billingCycle: .annual,
                        features: "~$7/мес, синяя галочка"),
                  .init(id: "premium_plus_monthly", name: "Premium+", amount: 16, billingCycle: .monthly,
                        features: "Приоритет в ленте, без рекламы"),
                  .init(id: "premium_plus_annual", name: "Premium+ (год)", amount: 168, billingCycle: .annual,
                        features: "~$14/мес, без рекламы"),
              ]),

        .init(id: "discord_nitro", displayName: "Discord Nitro",
              aliases: ["дискорд", "discord"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "community", "communication"],
              managementURL: URL(string: "https://discord.com/settings/premium"),
              brandColorHex: "#5865F2", clearbitDomain: "discord.com",
              plans: [
                  .init(id: "basic_monthly", name: "Nitro Basic", amount: 2.99, billingCycle: .monthly,
                        features: "Custom emoji, анимированный аватар"),
                  .init(id: "basic_annual", name: "Nitro Basic (год)", amount: 29.99, billingCycle: .annual,
                        features: "~$2.50/мес"),
                  .init(id: "nitro_monthly", name: "Nitro", amount: 9.99, billingCycle: .monthly,
                        features: "2 буста, файлы 500 МБ, HD-стриминг"),
                  .init(id: "nitro_annual", name: "Nitro (год)", amount: 99.99, billingCycle: .annual,
                        features: "~$8.33/мес, 2 буста"),
              ]),

        .init(id: "reddit_premium", displayName: "Reddit Premium",
              aliases: ["реддит"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["community", "social"],
              managementURL: URL(string: "https://www.reddit.com/premium"),
              brandColorHex: "#FF4500", clearbitDomain: "reddit.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", amount: 5.99, billingCycle: .monthly,
                        features: "Без рекламы, 700 монет/мес"),
                  .init(id: "annual", name: "Annual", amount: 49.99, billingCycle: .annual,
                        features: "~$4.17/мес"),
              ]),

        // MARK: Dating

        // Plans omitted — subscription prices vary significantly by region and App Store territory.
        // Users should enter their actual price when adding.
        .init(id: "grindr", displayName: "Grindr",
              aliases: ["grindr xtra", "grindr unlimited", "гриндер"],
              category: .other, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social", "lgbtq"],
              brandColorHex: "#F5A623", clearbitDomain: "grindr.com"),

        .init(id: "hornet", displayName: "Hornet",
              aliases: ["hornet plus", "hornet premium", "hornet max", "хорнет"],
              category: .other, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social", "lgbtq"],
              brandColorHex: "#EE3124", clearbitDomain: "hornet.com"),

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
