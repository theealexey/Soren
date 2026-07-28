import Foundation

// MARK: - Global Providers
//
// PRICING POLICY
// All plan reference prices are legacy catalog data only.
// Actual charges vary by country, App Store territory, payment method,
// promotional pricing, and whether the subscription is purchased on web
// vs. through Apple/Google (which add a platform fee on top).
// These values are not verified Regional Pricing and serve only as convenient starting points — users are expected
// to verify and correct their actual amount when adding a subscription.

extension ProviderCatalog {

    static let global: [ProviderTemplate] = applyingBundledLogoPresentations(to: [
        // MARK: Video
        .init(id: "netflix", displayName: "Netflix", aliases: ["нетфликс"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "popular"], managementURL: URL(string: "https://www.netflix.com/account"),
              brandColorHex: "#E50914", companyLogoFallbackDomain: "netflix.com",
              logoPresentation: .appIcon,
              plans: [
                  // US prices as of March 2026
                  .init(id: "standard_ads", name: "Standard с рекламой", referenceAmount: 8.99, billingCycle: .monthly, features: "1080p, 2 экрана"),
                  .init(id: "standard", name: "Standard", referenceAmount: 19.99, billingCycle: .monthly, features: "1080p, 2 экрана, скачивание"),
                  .init(id: "premium", name: "Premium", referenceAmount: 26.99, billingCycle: .monthly, features: "4K HDR, 4 экрана"),
              ]),

        .init(id: "youtube_premium", displayName: "YouTube Premium", aliases: ["ютуб", "youtube"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "ad-free", "popular"],
              brandColorHex: "#FF0000", companyLogoFallbackDomain: "youtube.com",
              logoPresentation: .appIcon,
              plans: [
                  // US prices raised April 2026
                  .init(id: "individual", name: "Individual", referenceAmount: 15.99, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", referenceAmount: 159.99, billingCycle: .annual, features: "Экономия ~$32"),
                  .init(id: "family", name: "Family", referenceAmount: 26.99, billingCycle: .monthly, features: "До 5 участников"),
                  .init(id: "student", name: "Student", referenceAmount: 8.99, billingCycle: .monthly),
              ]),

        .init(id: "disney_plus", displayName: "Disney+", aliases: ["дисней"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"],
              brandColorHex: "#113CCF", companyLogoFallbackDomain: "disneyplus.com",
              plans: [
                  // US simplified to 2 tiers as of late 2025; both include 4K HDR
                  .init(id: "with_ads", name: "С рекламой", referenceAmount: 11.99, billingCycle: .monthly, features: "4K HDR, реклама"),
                  .init(id: "standard", name: "Standard (без рекламы)", referenceAmount: 18.99, billingCycle: .monthly, features: "4K HDR, 4 экрана, скачивание"),
                  .init(id: "standard_annual", name: "Standard (год)", referenceAmount: 189.99, billingCycle: .annual, features: "4K HDR, 4 экрана"),
              ]),

        .init(id: "hbo_max", displayName: "Max (HBO)", aliases: ["hbo", "max"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming"],
              brandColorHex: "#002BE7", companyLogoFallbackDomain: "max.com",
              plans: [
                  // US prices as of 2026
                  .init(id: "with_ads", name: "С рекламой", referenceAmount: 10.99, billingCycle: .monthly, features: "FHD, 2 экрана"),
                  .init(id: "with_ads_annual", name: "С рекламой (год)", referenceAmount: 109.99, billingCycle: .annual, features: "FHD, 2 экрана"),
                  .init(id: "ad_free", name: "Без рекламы", referenceAmount: 18.49, billingCycle: .monthly, features: "FHD, 2 экрана"),
                  .init(id: "ad_free_annual", name: "Без рекламы (год)", referenceAmount: 184.99, billingCycle: .annual, features: "FHD, 2 экрана"),
                  .init(id: "ultimate", name: "Ultimate", referenceAmount: 22.99, billingCycle: .monthly, features: "4K, 4 экрана, Dolby Atmos"),
                  .init(id: "ultimate_annual", name: "Ultimate (год)", referenceAmount: 229.99, billingCycle: .annual, features: "4K, 4 экрана, Dolby Atmos"),
              ]),

        .init(id: "apple_tv_plus", displayName: "Apple TV+", aliases: ["apple tv", "эпл тв"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "apple"],
              brandColorHex: "#000000",
              plans: [
                  // Price raised to $12.99/month in August 2025
                  .init(id: "monthly", name: "Monthly", referenceAmount: 12.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 99.99, billingCycle: .annual, features: "Экономия ~$56"),
              ]),

        .init(id: "amazon_prime_video", displayName: "Amazon Prime Video", aliases: ["амазон", "prime video"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "amazon"],
              brandColorHex: "#00A8E1", companyLogoFallbackDomain: "primevideo.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 8.99, billingCycle: .monthly, features: "Только видео"),
              ]),

        .init(id: "crunchyroll", displayName: "Crunchyroll", aliases: ["кранчиролл", "аниме"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "anime"],
              brandColorHex: "#F47521", companyLogoFallbackDomain: "crunchyroll.com",
              plans: [
                  .init(id: "fan", name: "Fan", referenceAmount: 7.99, billingCycle: .monthly, features: "1 поток, без рекламы"),
                  .init(id: "mega_fan", name: "Mega Fan", referenceAmount: 9.99, billingCycle: .monthly, features: "4 потока, скачивание"),
                  .init(id: "ultimate_fan", name: "Ultimate Fan", referenceAmount: 14.99, billingCycle: .monthly, features: "Все функции + Funimation"),
              ]),

        .init(id: "mubi", displayName: "MUBI", aliases: ["муби"],
              category: .video, suggestedCurrencyCode: "USD", region: .global,
              tags: ["streaming", "arthouse"],
              brandColorHex: "#001B38", companyLogoFallbackDomain: "mubi.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 14.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 107.88, billingCycle: .annual, features: "Экономия ~$72"),
              ]),

        // MARK: Music
        .init(id: "spotify", displayName: "Spotify", aliases: ["спотифай"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "streaming", "popular"],
              brandColorHex: "#1DB954", companyLogoFallbackDomain: "spotify.com",
              logoPresentation: .appIcon,
              plans: [
                  // US prices raised January 2026
                  .init(id: "individual", name: "Individual", referenceAmount: 12.99, billingCycle: .monthly),
                  .init(id: "duo", name: "Duo", referenceAmount: 18.99, billingCycle: .monthly, features: "2 аккаунта"),
                  .init(id: "family", name: "Family", referenceAmount: 21.99, billingCycle: .monthly, features: "До 6 участников"),
                  .init(id: "student", name: "Student", referenceAmount: 6.99, billingCycle: .monthly),
              ]),

        .init(id: "apple_music", displayName: "Apple Music", aliases: ["эпл мьюзик"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "apple"],
              serviceLogoSourceURL: URL(string: "https://music.apple.com/favicon.ico"),
              brandColorHex: "#FC3C44",
              logoPresentation: .appIcon,
              plans: [
                  .init(id: "individual", name: "Individual", referenceAmount: 10.99, billingCycle: .monthly),
                  .init(id: "family", name: "Family", referenceAmount: 16.99, billingCycle: .monthly, features: "До 6 участников"),
                  .init(id: "student", name: "Student", referenceAmount: 5.99, billingCycle: .monthly),
              ]),

        .init(id: "tidal", displayName: "TIDAL", aliases: ["тайдал"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "hifi"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "tidal.com",
              logoPresentation: .bakedTile,
              plans: [
                  // HiFi and HiFi+ merged into a single plan (April 2024)
                  .init(id: "individual", name: "Individual", referenceAmount: 10.99, billingCycle: .monthly, features: "Lossless, HiRes 24-bit, Dolby Atmos"),
                  .init(id: "family", name: "Family", referenceAmount: 16.99, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "deezer", displayName: "Deezer", aliases: ["дизер"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#A238FF", companyLogoFallbackDomain: "deezer.com",
              plans: [
                  .init(id: "individual", name: "Individual", referenceAmount: 10.99, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", referenceAmount: 107.99, billingCycle: .annual, features: "Экономия ~$24"),
                  .init(id: "duo", name: "Duo", referenceAmount: 14.99, billingCycle: .monthly, features: "2 аккаунта"),
                  .init(id: "family", name: "Family", referenceAmount: 17.99, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "soundcloud_go", displayName: "SoundCloud Go+", aliases: ["саундклауд"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music"],
              brandColorHex: "#FF5500", companyLogoFallbackDomain: "soundcloud.com",
              plans: [
                  .init(id: "go", name: "Go", referenceAmount: 5.99, billingCycle: .monthly, features: "Без рекламы"),
                  .init(id: "go_plus", name: "Go+", referenceAmount: 9.99, billingCycle: .monthly, features: "Оффлайн, Hi-Q аудио"),
              ]),

        .init(id: "qobuz", displayName: "Qobuz", aliases: ["кобуз"],
              category: .music, suggestedCurrencyCode: "USD", region: .global,
              tags: ["music", "hifi", "lossless"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "qobuz.com",
              logoPresentation: .bakedTile,
              plans: [
                  .init(id: "studio", name: "Studio", referenceAmount: 12.99, billingCycle: .monthly, features: "Hi-Res 24-bit, без рекламы"),
                  .init(id: "studio_annual", name: "Studio (год)", referenceAmount: 129.99, billingCycle: .annual, features: "Hi-Res 24-bit, без рекламы"),
              ]),

        // MARK: Cloud
        .init(id: "icloud", displayName: "iCloud+", aliases: ["айклауд", "icloud"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "storage", "popular"],
              serviceLogoSourceURL: URL(string: "https://www.icloud.com/favicon.ico"),
              brandColorHex: "#3693F5",
              logoPresentation: .appIcon,
              plans: [
                  .init(id: "50gb", name: "50 ГБ", referenceAmount: 0.99, billingCycle: .monthly),
                  .init(id: "200gb", name: "200 ГБ", referenceAmount: 2.99, billingCycle: .monthly),
                  .init(id: "2tb", name: "2 ТБ", referenceAmount: 9.99, billingCycle: .monthly),
                  .init(id: "6tb", name: "6 ТБ", referenceAmount: 29.99, billingCycle: .monthly),
                  .init(id: "12tb", name: "12 ТБ", referenceAmount: 59.99, billingCycle: .monthly),
              ]),

        .init(id: "google_one", displayName: "Google One", aliases: ["гугл один", "google drive"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["google", "storage"],
              brandColorHex: "#4285F4", companyLogoFallbackDomain: "google.com",
              plans: [
                  .init(id: "100gb", name: "100 ГБ", referenceAmount: 1.99, billingCycle: .monthly),
                  .init(id: "100gb_annual", name: "100 ГБ (год)", referenceAmount: 19.99, billingCycle: .annual, features: "Экономия ~$4"),
                  .init(id: "200gb", name: "200 ГБ", referenceAmount: 2.99, billingCycle: .monthly),
                  .init(id: "200gb_annual", name: "200 ГБ (год)", referenceAmount: 29.99, billingCycle: .annual, features: "Экономия ~$6"),
                  .init(id: "2tb", name: "2 ТБ", referenceAmount: 9.99, billingCycle: .monthly),
                  .init(id: "2tb_annual", name: "2 ТБ (год)", referenceAmount: 99.99, billingCycle: .annual, features: "Экономия ~$20"),
                  .init(id: "5tb", name: "5 ТБ", referenceAmount: 24.99, billingCycle: .monthly),
                  .init(id: "10tb", name: "10 ТБ", referenceAmount: 49.99, billingCycle: .monthly),
              ]),

        .init(id: "dropbox", displayName: "Dropbox", aliases: ["дропбокс"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["storage"],
              brandColorHex: "#0061FF", companyLogoFallbackDomain: "dropbox.com",
              plans: [
                  .init(id: "plus", name: "Plus", referenceAmount: 11.99, billingCycle: .monthly, features: "2 ТБ, 1 пользователь"),
                  .init(id: "plus_annual", name: "Plus (год)", referenceAmount: 119.88, billingCycle: .annual, features: "2 ТБ, 1 пользователь"),
                  .init(id: "professional", name: "Professional", referenceAmount: 19.99, billingCycle: .monthly, features: "3 ТБ, eSign, расширенный поиск"),
              ]),

        .init(id: "onedrive", displayName: "Microsoft OneDrive", aliases: ["уандрайв"],
              category: .cloud, suggestedCurrencyCode: "USD", region: .global,
              tags: ["microsoft", "storage"],
              brandColorHex: "#0078D4",
              plans: [
                  .init(id: "100gb", name: "100 ГБ", referenceAmount: 1.99, billingCycle: .monthly),
                  .init(id: "m365_personal", name: "Microsoft 365 Personal", referenceAmount: 6.99, billingCycle: .monthly, features: "1 ТБ + Office-приложения"),
                  .init(id: "m365_family", name: "Microsoft 365 Family", referenceAmount: 9.99, billingCycle: .monthly, features: "До 6 чел., 1 ТБ каждому"),
              ]),

        // MARK: AI Tools
        .init(id: "chatgpt_plus", displayName: "ChatGPT Plus", aliases: ["чатгпт", "openai", "gpt"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "popular"],
              brandColorHex: "#10A37F", companyLogoFallbackDomain: "openai.com",
              logoPresentation: .appIcon,
              plans: [
                  // Go ($8) and Pro-100 ($100) added in 2026
                  .init(id: "go", name: "Go", referenceAmount: 8, billingCycle: .monthly, features: "Базовый доступ к моделям"),
                  .init(id: "plus", name: "Plus", referenceAmount: 20, billingCycle: .monthly),
                  .init(id: "team", name: "Business", referenceAmount: 25, billingCycle: .monthly, features: "Расширенные лимиты, управление"),
                  .init(id: "pro_100", name: "Pro", referenceAmount: 100, billingCycle: .monthly, features: "5× лимиты Plus, продвинутые модели"),
                  .init(id: "pro", name: "Pro Max", referenceAmount: 200, billingCycle: .monthly, features: "20× лимиты Plus, безлимитный доступ"),
              ]),

        .init(id: "claude_pro", displayName: "Claude Pro", aliases: ["клод", "anthropic"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai"],
              brandColorHex: "#D97757", companyLogoFallbackDomain: "anthropic.com",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 20, billingCycle: .monthly),
                  .init(id: "max_5x", name: "Max (5×)", referenceAmount: 100, billingCycle: .monthly, features: "5× лимиты Pro, приоритет"),
                  .init(id: "max_20x", name: "Max (20×)", referenceAmount: 200, billingCycle: .monthly, features: "20× лимиты Pro"),
              ]),

        .init(id: "midjourney", displayName: "Midjourney", aliases: ["миджорни"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "image"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "midjourney.com",
              plans: [
                  .init(id: "basic", name: "Basic", referenceAmount: 10, billingCycle: .monthly, features: "~200 изображений/мес"),
                  .init(id: "standard", name: "Standard", referenceAmount: 30, billingCycle: .monthly, features: "15 ч. GPU, безлимит (relax)"),
                  .init(id: "pro", name: "Pro", referenceAmount: 60, billingCycle: .monthly, features: "30 ч. GPU, stealth mode"),
                  .init(id: "mega", name: "Mega", referenceAmount: 120, billingCycle: .monthly, features: "60 ч. GPU"),
              ]),

        .init(id: "github_copilot", displayName: "GitHub Copilot", aliases: ["копайлот", "copilot"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "github.com",
              plans: [
                  // Copilot Pro+ ($39/mo) added 2025; annual Copilot Pro = $100/year
                  .init(id: "individual", name: "Copilot Pro", referenceAmount: 10, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Copilot Pro (год)", referenceAmount: 100, billingCycle: .annual),
                  .init(id: "pro_plus", name: "Copilot Pro+", referenceAmount: 39, billingCycle: .monthly, features: "Расширенные модели, большие контексты"),
                  .init(id: "business", name: "Business", referenceAmount: 19, billingCycle: .monthly, features: "Управление командой, политики"),
              ]),

        .init(id: "cursor", displayName: "Cursor", aliases: ["курсор"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "dev"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "cursor.com",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 20, billingCycle: .monthly, features: "500 быстрых запросов/мес"),
                  .init(id: "business", name: "Business", referenceAmount: 40, billingCycle: .monthly, features: "Privacy mode, SSO, аудит"),
              ]),

        .init(id: "perplexity", displayName: "Perplexity Pro", aliases: ["перплексити"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "search"],
              brandColorHex: "#20808D", companyLogoFallbackDomain: "perplexity.ai",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 20, billingCycle: .monthly, features: "GPT-4o, Claude, безлимит поиска"),
              ]),

        .init(id: "notion_ai", displayName: "Notion AI", aliases: ["ноушен"],
              category: .aiTools, suggestedCurrencyCode: "USD", region: .global,
              tags: ["ai", "productivity"],
              brandColorHex: "#000000",
              plans: [
                  .init(id: "ai_addon", name: "AI Add-on", referenceAmount: 10, billingCycle: .monthly, features: "На одного участника"),
              ]),

        // MARK: Productivity
        .init(id: "notion", displayName: "Notion", aliases: ["ноушен"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["notes", "workspace"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "notion.so",
              plans: [
                  .init(id: "plus", name: "Plus", referenceAmount: 10, billingCycle: .monthly, features: "Безлимитные страницы и блоки"),
                  .init(id: "business", name: "Business", referenceAmount: 18, billingCycle: .monthly, features: "SAML SSO, экспорт PDF"),
              ]),

        .init(id: "figma", displayName: "Figma", aliases: ["фигма"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"],
              brandColorHex: "#F24E1E", companyLogoFallbackDomain: "figma.com"),

        .init(id: "linear", displayName: "Linear", aliases: ["линеар"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["project-management"],
              brandColorHex: "#5E6AD2", companyLogoFallbackDomain: "linear.app"),

        .init(id: "slack", displayName: "Slack", aliases: ["слак"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication"],
              brandColorHex: "#4A154B", companyLogoFallbackDomain: "slack.com",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 8.75, billingCycle: .monthly, features: "Полная история, голосовые каналы"),
                  .init(id: "business_plus", name: "Business+", referenceAmount: 15, billingCycle: .monthly, features: "SAML SSO, 24/7 поддержка"),
              ]),

        .init(id: "zoom", displayName: "Zoom", aliases: ["зум"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["communication", "video"],
              brandColorHex: "#0B5CFF", companyLogoFallbackDomain: "zoom.us",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 14.99, billingCycle: .monthly, features: "30 ч. встречи, 1 ГБ облако"),
                  .init(id: "business", name: "Business", referenceAmount: 21.99, billingCycle: .monthly, features: "До 300 участников, транскрипция"),
              ]),

        .init(id: "microsoft_365", displayName: "Microsoft 365", aliases: ["office", "office 365", "ms 365"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["office", "microsoft"],
              brandColorHex: "#D83B01",
              companyLogoFallbackDomain: "www.microsoft365.com",
              plans: [
                  .init(id: "personal", name: "Personal", referenceAmount: 6.99, billingCycle: .monthly, features: "1 ТБ, Office для 1 чел."),
                  .init(id: "personal_annual", name: "Personal (год)", referenceAmount: 99.99, billingCycle: .annual, features: "1 ТБ, Office для 1 чел."),
                  .init(id: "family", name: "Family", referenceAmount: 9.99, billingCycle: .monthly, features: "До 6 чел., 1 ТБ каждому"),
                  .init(id: "family_annual", name: "Family (год)", referenceAmount: 129.99, billingCycle: .annual, features: "До 6 чел., 1 ТБ каждому"),
              ]),

        .init(id: "1password", displayName: "1Password", aliases: ["ванпассворд"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["security", "passwords"],
              brandColorHex: "#0572EC", companyLogoFallbackDomain: "1password.com",
              plans: [
                  // Prices raised March 27, 2026
                  .init(id: "individual", name: "Individual", referenceAmount: 3.99, billingCycle: .monthly),
                  .init(id: "families", name: "Families", referenceAmount: 5.99, billingCycle: .monthly, features: "До 5 участников"),
              ]),

        .init(id: "canva", displayName: "Canva Pro", aliases: ["канва"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design"],
              brandColorHex: "#00C4CC", companyLogoFallbackDomain: "canva.com",
              plans: [
                  .init(id: "pro", name: "Pro", referenceAmount: 12.99, billingCycle: .monthly, features: "100 ГБ, 420K шаблонов, бренд-кит"),
                  .init(id: "teams", name: "Teams", referenceAmount: 14.99, billingCycle: .monthly, features: "На участника, совместный бренд-кит"),
              ]),

        .init(id: "adobe_cc", displayName: "Adobe Creative Cloud", aliases: ["адоби", "фотошоп", "photoshop"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["design", "creative"],
              brandColorHex: "#FF0000", companyLogoFallbackDomain: "adobe.com",
              plans: [
                  // "All Apps" renamed to "Creative Cloud Pro" on August 1, 2025
                  .init(id: "photography", name: "Photography", referenceAmount: 19.99, billingCycle: .monthly, features: "Lightroom + Photoshop, 20 ГБ"),
                  .init(id: "all_apps", name: "Creative Cloud Pro", referenceAmount: 69.99, billingCycle: .monthly, features: "Все 20+ приложений, 100 ГБ"),
              ]),

        .init(id: "telegram_premium", displayName: "Telegram Premium",
              aliases: ["телеграм", "telegram"],
              category: .productivity, suggestedCurrencyCode: "USD", region: .global,
              tags: ["messaging", "communication"],
              brandColorHex: "#2CA5E0", companyLogoFallbackDomain: "telegram.org",
              plans: [
                  // Telegram FAQ: "price depends on your country and region."
                  // No universal default; users must enter their actual charge.
                  .init(id: "monthly", name: "Monthly", referenceAmount: 0, billingCycle: .monthly,
                        features: "Файлы до 4 ГБ, без рекламы, Premium-стикеры"),
                  .init(id: "annual", name: "Annual", referenceAmount: 0, billingCycle: .annual,
                        features: "Файлы до 4 ГБ, без рекламы, Premium-стикеры"),
              ]),

        // MARK: VPN & Security
        .init(id: "nordvpn", displayName: "NordVPN", aliases: ["норд"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn", "popular"],
              brandColorHex: "#4687FF", companyLogoFallbackDomain: "nordvpn.com",
              plans: [
                  // Basic tier reference prices (US 2026)
                  .init(id: "monthly", name: "Monthly", referenceAmount: 12.99, billingCycle: .monthly, features: "6 устройств"),
                  .init(id: "annual", name: "Annual", referenceAmount: 59.88, billingCycle: .annual, features: "~$4.99/мес"),
              ]),

        .init(id: "surfshark", displayName: "Surfshark", aliases: ["серфшарк"],
              category: .vpn, suggestedCurrencyCode: "USD", region: .global,
              tags: ["vpn"],
              brandColorHex: "#178BF1", companyLogoFallbackDomain: "surfshark.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 15.45, billingCycle: .monthly, features: "Безлимитные устройства"),
                  .init(id: "annual", name: "Annual", referenceAmount: 47.88, billingCycle: .annual, features: "~$3.99/мес"),
              ]),

        .init(id: "mullvad", displayName: "Mullvad VPN", aliases: ["мулвад"],
              category: .vpn, suggestedCurrencyCode: "EUR", region: .global,
              tags: ["vpn", "privacy"],
              brandColorHex: "#294D73", companyLogoFallbackDomain: "mullvad.net",
              plans: [
                  .init(id: "standard", name: "Standard", referenceAmount: 5, billingCycle: .monthly, features: "Без аккаунта, анонимно"),
              ]),

        // MARK: Shopping
        .init(id: "amazon_prime", displayName: "Amazon Prime", aliases: ["амазон прайм"],
              category: .shopping, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery", "amazon"],
              brandColorHex: "#FF9900",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 14.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 139, billingCycle: .annual, features: "Экономия ~$41"),
              ]),

        // MARK: Games
        .init(id: "ps_plus", displayName: "PlayStation Plus", aliases: ["ps plus", "пс плюс", "playstation"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#003087", companyLogoFallbackDomain: "playstation.com",
              plans: [
                  .init(id: "essential", name: "Essential", referenceAmount: 9.99, billingCycle: .monthly, features: "2 игры/мес, онлайн мультиплеер"),
                  .init(id: "essential_annual", name: "Essential (год)", referenceAmount: 79.99, billingCycle: .annual, features: "2 игры/мес, онлайн мультиплеер"),
                  .init(id: "extra", name: "Extra", referenceAmount: 14.99, billingCycle: .monthly, features: "Каталог 400+ игр"),
                  .init(id: "extra_annual", name: "Extra (год)", referenceAmount: 134.99, billingCycle: .annual, features: "Каталог 400+ игр"),
                  .init(id: "premium", name: "Premium", referenceAmount: 17.99, billingCycle: .monthly, features: "Классика PS1–PS4, стриминг"),
                  .init(id: "premium_annual", name: "Premium (год)", referenceAmount: 159.99, billingCycle: .annual, features: "Классика PS1–PS4, стриминг"),
              ]),

        .init(id: "xbox_gamepass", displayName: "Xbox Game Pass", aliases: ["геймпас", "game pass"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "microsoft"],
              brandColorHex: "#107C10", companyLogoFallbackDomain: "xbox.com",
              plans: [
                  // Ultimate dropped from $29.99 to $22.99 on April 21, 2026
                  .init(id: "core", name: "Core", referenceAmount: 9.99, billingCycle: .monthly, features: "Онлайн + 25 классических игр"),
                  .init(id: "standard", name: "Standard", referenceAmount: 14.99, billingCycle: .monthly, features: "Каталог PC + Console"),
                  .init(id: "ultimate", name: "Ultimate", referenceAmount: 22.99, billingCycle: .monthly, features: "PC + Console + EA Play + Cloud"),
              ]),

        .init(id: "nintendo_online", displayName: "Nintendo Switch Online", aliases: ["нинтендо"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming"],
              brandColorHex: "#E60012", companyLogoFallbackDomain: "nintendo.com",
              plans: [
                  .init(id: "individual_monthly", name: "Individual", referenceAmount: 3.99, billingCycle: .monthly),
                  .init(id: "individual_annual", name: "Individual (год)", referenceAmount: 19.99, billingCycle: .annual),
                  .init(id: "family_annual", name: "Family (год)", referenceAmount: 34.99, billingCycle: .annual, features: "До 8 аккаунтов"),
              ]),

        .init(id: "apple_arcade", displayName: "Apple Arcade", aliases: ["эпл аркейд"],
              category: .games, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "apple"],
              brandColorHex: "#0070C9",
              logoPresentation: .appIcon,
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 6.99, billingCycle: .monthly, features: "200+ игр, до 6 чел."),
                  .init(id: "annual", name: "Annual", referenceAmount: 49.99, billingCycle: .annual, features: "200+ игр, до 6 чел., экономия ~$34"),
              ]),

        // MARK: Health
        .init(id: "strava", displayName: "Strava", aliases: ["страва"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness"],
              brandColorHex: "#FC4C02", companyLogoFallbackDomain: "strava.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 11.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 79.99, billingCycle: .annual, features: "Экономия ~$64"),
              ]),

        .init(id: "headspace", displayName: "Headspace", aliases: ["хедспейс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["meditation"],
              brandColorHex: "#F47D31", companyLogoFallbackDomain: "headspace.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 12.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 69.99, billingCycle: .annual, features: "Экономия ~$86"),
              ]),

        .init(id: "apple_fitness_plus", displayName: "Apple Fitness+", aliases: ["фитнес плюс"],
              category: .health, suggestedCurrencyCode: "USD", region: .global,
              tags: ["fitness", "apple"],
              brandColorHex: "#97D608",
              logoPresentation: .appIcon,
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 9.99, billingCycle: .monthly),
                  .init(id: "annual", name: "Annual", referenceAmount: 79.99, billingCycle: .annual, features: "Экономия ~$40"),
              ]),

        // MARK: Education
        .init(id: "duolingo", displayName: "Duolingo Plus", aliases: ["дуолинго"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["language"],
              brandColorHex: "#58CC02", companyLogoFallbackDomain: "duolingo.com",
              plans: [
                  // US prices as of 2026; Duolingo Max added (AI roleplay + video calls)
                  .init(id: "super_monthly", name: "Super", referenceAmount: 12.99, billingCycle: .monthly, features: "Без рекламы, безлимитные жизни"),
                  .init(id: "super_annual", name: "Super (год)", referenceAmount: 83.99, billingCycle: .annual),
                  .init(id: "max_monthly", name: "Max", referenceAmount: 29.99, billingCycle: .monthly, features: "Super + AI roleplay, видео-звонки"),
                  .init(id: "max_annual", name: "Max (год)", referenceAmount: 168, billingCycle: .annual, features: "Super + AI roleplay, видео-звонки"),
                  .init(id: "family", name: "Family", referenceAmount: 119.99, billingCycle: .annual, features: "До 6 участников"),
              ]),

        .init(id: "coursera", displayName: "Coursera Plus", aliases: ["курсера"],
              category: .education, suggestedCurrencyCode: "USD", region: .global,
              tags: ["courses"],
              brandColorHex: "#0056D2", companyLogoFallbackDomain: "coursera.org",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 59, billingCycle: .monthly, features: "Все курсы и сертификаты"),
                  .init(id: "annual", name: "Annual", referenceAmount: 399, billingCycle: .annual, features: "Экономия ~$309"),
              ]),

        // MARK: Books
        .init(id: "kindle_unlimited", displayName: "Kindle Unlimited", aliases: ["киндл"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["books", "amazon"],
              brandColorHex: "#FF9900",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 11.99, billingCycle: .monthly, features: "1M+ книг и журналов"),
              ]),

        .init(id: "audible", displayName: "Audible", aliases: ["аудибл", "аудиокниги"],
              category: .books, suggestedCurrencyCode: "USD", region: .global,
              tags: ["audiobooks", "amazon"],
              brandColorHex: "#F8991D", companyLogoFallbackDomain: "audible.com",
              plans: [
                  .init(id: "plus", name: "Plus", referenceAmount: 7.95, billingCycle: .monthly, features: "Безлимитный каталог Plus"),
                  .init(id: "premium_plus", name: "Premium Plus", referenceAmount: 14.95, billingCycle: .monthly, features: "1 кредит/мес + каталог Plus"),
              ]),

        // MARK: Food
        .init(id: "uber_eats_pass", displayName: "Uber One", aliases: ["убер"],
              category: .food, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["delivery"],
              brandColorHex: "#000000", companyLogoFallbackDomain: "uber.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 9.99, billingCycle: .monthly, features: "Без комиссии доставки"),
                  .init(id: "annual", name: "Annual", referenceAmount: 99, billingCycle: .annual, features: "Экономия ~$21"),
              ]),

        // MARK: Creators & Donations
        .init(id: "patreon", displayName: "Patreon", aliases: ["патреон"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#FF424D", companyLogoFallbackDomain: "patreon.com"),

        .init(id: "twitch_sub", displayName: "Twitch Subscriptions", aliases: ["твич", "twitch"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "streaming"],
              brandColorHex: "#9146FF", companyLogoFallbackDomain: "twitch.tv"),

        .init(id: "youtube_membership", displayName: "YouTube Memberships", aliases: ["ютуб мемберство"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "youtube"],
              brandColorHex: "#FF0000", companyLogoFallbackDomain: "youtube.com"),

        .init(id: "ko_fi", displayName: "Ko-fi", aliases: ["кофи"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#13C3FF", companyLogoFallbackDomain: "ko-fi.com"),

        .init(id: "buy_me_a_coffee", displayName: "Buy Me a Coffee", aliases: ["бай ми э кофе", "bmac"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "donations"],
              brandColorHex: "#FFDD00", companyLogoFallbackDomain: "buymeacoffee.com"),

        .init(id: "substack", displayName: "Substack", aliases: ["сабстак"],
              category: .creators, itemType: .membership, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators", "newsletter"],
              brandColorHex: "#FF6719", companyLogoFallbackDomain: "substack.com"),

        .init(id: "onlyfans", displayName: "OnlyFans", aliases: ["онлифанс"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["creators"],
              brandColorHex: "#00AFF0", companyLogoFallbackDomain: "onlyfans.com"),

        // MARK: Social & Creator Platforms

        .init(id: "meta_verified", displayName: "Meta Verified",
              aliases: ["instagram", "facebook", "meta", "verified",
                        "инстаграм", "фейсбук", "мета"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["social", "creator", "verified"],
              managementURL: URL(string: "https://www.meta.com/verified"),
              brandColorHex: "#0866FF", companyLogoFallbackDomain: "meta.com",
              logoPresentation: .adaptiveGlyph,
              plans: [
                  // Prices are per-profile, US-web only, and vary significantly by country
                  // and platform (iOS App Store adds ~30%). No reliable default exists.
                  // Users must enter their actual charged amount.
                  .init(id: "standard", name: "Standard", referenceAmount: 0, billingCycle: .monthly,
                        features: "Verified badge, поддержка аккаунта"),
                  .init(id: "plus", name: "Plus", referenceAmount: 0, billingCycle: .monthly,
                        features: "Standard + продвижение профиля, ссылки в Reels"),
                  .init(id: "premium", name: "Premium", referenceAmount: 0, billingCycle: .monthly,
                        features: "Plus + Stars, эксклюзивные стикеры, монетизация"),
                  .init(id: "max", name: "Max", referenceAmount: 0, billingCycle: .monthly,
                        features: "Полный пакет монетизации и поддержки"),
              ]),

        .init(id: "x_premium", displayName: "X Premium",
              aliases: ["x", "twitter", "twitter blue", "твиттер", "твиттер блю", "premium+"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["social", "creator", "twitter"],
              managementURL: URL(string: "https://x.com/settings/premium"),
              brandColorHex: "#000000", companyLogoFallbackDomain: "x.com",
              logoPresentation: .appIcon,
              plans: [
                  // US prices at x.com/i/premium; Premium+ doubled in Feb 2025 (Grok 3)
                  .init(id: "basic_monthly", name: "Basic", referenceAmount: 3, billingCycle: .monthly),
                  .init(id: "basic_annual", name: "Basic (год)", referenceAmount: 32, billingCycle: .annual,
                        features: "~$2.67/мес"),
                  .init(id: "premium_monthly", name: "Premium", referenceAmount: 8, billingCycle: .monthly,
                        features: "Синяя галочка, расширенные посты"),
                  .init(id: "premium_annual", name: "Premium (год)", referenceAmount: 84, billingCycle: .annual,
                        features: "~$7/мес, синяя галочка"),
                  .init(id: "premium_plus_monthly", name: "Premium+", referenceAmount: 40, billingCycle: .monthly,
                        features: "Grok 3, приоритет в ленте, без рекламы"),
                  .init(id: "premium_plus_annual", name: "Premium+ (год)", referenceAmount: 395, billingCycle: .annual,
                        features: "~$32.92/мес, Grok 3, без рекламы"),
              ]),

        .init(id: "discord_nitro", displayName: "Discord Nitro",
              aliases: ["дискорд", "discord"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["gaming", "community", "communication"],
              managementURL: URL(string: "https://discord.com/settings/premium"),
              brandColorHex: "#5865F2", companyLogoFallbackDomain: "discord.com",
              plans: [
                  .init(id: "basic_monthly", name: "Nitro Basic", referenceAmount: 2.99, billingCycle: .monthly,
                        features: "Custom emoji, анимированный аватар"),
                  .init(id: "basic_annual", name: "Nitro Basic (год)", referenceAmount: 29.99, billingCycle: .annual,
                        features: "~$2.50/мес"),
                  .init(id: "nitro_monthly", name: "Nitro", referenceAmount: 9.99, billingCycle: .monthly,
                        features: "2 буста, файлы 500 МБ, HD-стриминг"),
                  .init(id: "nitro_annual", name: "Nitro (год)", referenceAmount: 99.99, billingCycle: .annual,
                        features: "~$8.33/мес, 2 буста"),
              ]),

        .init(id: "reddit_premium", displayName: "Reddit Premium",
              aliases: ["реддит"],
              category: .creators, suggestedCurrencyCode: "USD", region: .global,
              tags: ["community", "social"],
              managementURL: URL(string: "https://www.reddit.com/premium"),
              brandColorHex: "#FF4500", companyLogoFallbackDomain: "reddit.com",
              plans: [
                  .init(id: "monthly", name: "Monthly", referenceAmount: 5.99, billingCycle: .monthly,
                        features: "Без рекламы, 700 монет/мес"),
                  .init(id: "annual", name: "Annual", referenceAmount: 49.99, billingCycle: .annual,
                        features: "~$4.17/мес"),
              ]),

        // MARK: Dating

        .init(id: "grindr", displayName: "Grindr",
              aliases: ["grindr xtra", "grindr unlimited", "гриндер"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social", "lgbtq"],
              brandColorHex: "#F5A623", companyLogoFallbackDomain: "grindr.com"),

        .init(id: "hornet", displayName: "Hornet",
              aliases: ["hornet plus", "hornet premium", "hornet max", "хорнет"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social", "lgbtq"],
              brandColorHex: "#EE3124", companyLogoFallbackDomain: "hornet.com"),

        .init(id: "tinder", displayName: "Tinder",
              aliases: ["тиндер"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social"],
              managementURL: URL(string: "https://tinder.com"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/e1/66/97/e1669740-5fd9-c155-0db4-56bfa0d26a71/AppIcon-BrandFlame-0-0-1x_U007ephone-0-1-0-0-sRGB-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#E9425D"),

        .init(id: "bumble", displayName: "Bumble",
              aliases: ["бамбл"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social"],
              managementURL: URL(string: "https://bumble.com"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/00/02/69/000269f5-f54d-c73b-1d8c-36e0cfa7c685/AppIcon-0-0-1x_U007ephone-0-1-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#FFCB37"),

        .init(id: "hinge", displayName: "Hinge",
              aliases: ["хиндж"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social"],
              managementURL: URL(string: "https://hinge.co"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/71/66/44/7166446a-3ab4-d12a-b388-841290862056/AppIcon-0-0-1x_U007emarketing-0-6-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#1A1A1A"),

        .init(id: "badoo", displayName: "Badoo",
              aliases: ["баду"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social"],
              managementURL: URL(string: "https://badoo.com"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple221/v4/87/87/d7/8787d7bc-54ab-2710-0152-1aa61e15f15a/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#D50032"),

        .init(id: "feeld", displayName: "Feeld",
              aliases: ["филд"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social"],
              managementURL: URL(string: "https://feeld.co"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/3f/66/0c/3f660ccb-a49a-94fc-bb31-ff8408e63089/AppIcon-0-0-1x_U007ephone-0-12-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#4938C9"),

        .init(id: "her", displayName: "HER",
              aliases: ["her dating", "хер"],
              category: .dating, suggestedCurrencyCode: "USD", region: .global,
              tags: ["dating", "social", "lgbtq"],
              managementURL: URL(string: "https://weareher.com"),
              serviceLogoSourceURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/18/44/31/18443194-6fc5-2ae7-385f-52d6483a2db9/AppIcon-0-0-1x_U007emarketing-0-8-0-85-220.png/512x512bb.jpg"),
              brandColorHex: "#E2231A"),

        // MARK: Apple Bundles
        .init(id: "apple_one", displayName: "Apple One", aliases: ["эпл ван"],
              category: .cloud, itemType: .ecosystemBundle, suggestedCurrencyCode: "USD", region: .global,
              tags: ["apple", "bundle"],
              brandColorHex: "#000000",
              plans: [
                  .init(id: "individual", name: "Individual", referenceAmount: 19.95, billingCycle: .monthly, features: "Music, TV+, Arcade, iCloud+ 50 ГБ"),
                  .init(id: "family", name: "Family", referenceAmount: 25.95, billingCycle: .monthly, features: "До 6 чел., iCloud+ 200 ГБ"),
                  .init(id: "premier", name: "Premier", referenceAmount: 37.95, billingCycle: .monthly, features: "Все + News+, Fitness+, iCloud+ 2 ТБ"),
              ]),
    ])
}
