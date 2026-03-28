import Foundation

// MARK: - Russian Market Providers

extension ProviderCatalog {

    static let russia: [ProviderTemplate] = [

        // ────────────────────────────────────────
        // MARK: Экосистемы и бандлы
        // ────────────────────────────────────────

        .init(id: "yandex_plus", displayName: "Яндекс Плюс",
              aliases: ["яндекс", "yandex plus", "yandex+"],
              category: .shopping, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "bundle", "cashback", "popular"]),

        .init(id: "sber_prime", displayName: "СберПрайм+",
              aliases: ["сбер прайм", "sberprime", "sber"],
              category: .banking, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "banking", "bundle"]),

        .init(id: "mts_premium", displayName: "МТС Premium",
              aliases: ["мтс премиум", "mts premium"],
              category: .mobile, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "telecom", "bundle", "popular"]),

        .init(id: "tbank_pro", displayName: "Т-Банк Pro",
              aliases: ["т-банк", "tinkoff pro", "тинькофф про", "t-bank"],
              category: .banking, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["banking", "cashback"]),

        // ────────────────────────────────────────
        // MARK: Видео
        // ────────────────────────────────────────

        .init(id: "kinopoisk", displayName: "Кинопоиск",
              aliases: ["кп", "kinopoisk"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "yandex"]),

        .init(id: "okko", displayName: "Okko",
              aliases: ["окко"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"]),

        .init(id: "wink", displayName: "Wink",
              aliases: ["винк"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "rostelecom"]),

        .init(id: "kion", displayName: "KION",
              aliases: ["кион"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "mts"]),

        .init(id: "start", displayName: "START",
              aliases: ["старт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"]),

        .init(id: "premier", displayName: "PREMIER",
              aliases: ["премьер", "тнт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"]),

        .init(id: "ivi", displayName: "IVI",
              aliases: ["иви"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"]),

        // ────────────────────────────────────────
        // MARK: Музыка
        // ────────────────────────────────────────

        .init(id: "yandex_music", displayName: "Яндекс Музыка",
              aliases: ["яндекс музыка", "yandex music"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "yandex"]),

        .init(id: "zvuk", displayName: "Звук",
              aliases: ["zvuk", "сбер звук"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "sber"]),

        .init(id: "vk_music", displayName: "VK Музыка",
              aliases: ["вк музыка", "vk music", "boom"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "vk"]),

        // ────────────────────────────────────────
        // MARK: Маркетплейсы
        // ────────────────────────────────────────

        .init(id: "ozon_premium", displayName: "Ozon Premium",
              aliases: ["озон", "ozon"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "delivery"]),

        .init(id: "wb_club", displayName: "WB Клуб",
              aliases: ["вайлдберриз", "wildberries", "wb"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace"]),

        .init(id: "yandex_market_plus", displayName: "Яндекс Маркет Плюс",
              aliases: ["яндекс маркет", "yandex market"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "yandex"]),

        .init(id: "samokat", displayName: "Самокат Плюс",
              aliases: ["samokat"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "grocery"]),

        // ────────────────────────────────────────
        // MARK: Мобильные операторы
        // ────────────────────────────────────────

        .init(id: "mts", displayName: "МТС",
              aliases: ["mts"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"]),

        .init(id: "megafon", displayName: "МегаФон",
              aliases: ["мегафон", "megafon"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"]),

        .init(id: "beeline", displayName: "Билайн",
              aliases: ["beeline", "билайн"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"]),

        .init(id: "t2", displayName: "Т2 (Tele2)",
              aliases: ["tele2", "теле2", "т2"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"]),

        .init(id: "yota", displayName: "Yota",
              aliases: ["йота"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"]),

        // ────────────────────────────────────────
        // MARK: Облако
        // ────────────────────────────────────────

        .init(id: "yandex_disk", displayName: "Яндекс Диск",
              aliases: ["яндекс диск", "yandex disk"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "yandex"]),

        .init(id: "mail_cloud", displayName: "Облако Mail.ru",
              aliases: ["облако mail", "mail cloud", "vk cloud"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "vk"]),

        // ────────────────────────────────────────
        // MARK: Образование
        // ────────────────────────────────────────

        .init(id: "skillbox", displayName: "Skillbox",
              aliases: ["скиллбокс"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"]),

        .init(id: "stepik", displayName: "Stepik",
              aliases: ["степик"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"]),

        .init(id: "practicum", displayName: "Яндекс Практикум",
              aliases: ["практикум", "yandex practicum"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses", "yandex"]),

        // ────────────────────────────────────────
        // MARK: Книги
        // ────────────────────────────────────────

        .init(id: "litres", displayName: "ЛитРес",
              aliases: ["litres", "литрес"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books", "audiobooks"]),

        .init(id: "bookmate", displayName: "Bookmate",
              aliases: ["букмейт"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books"]),

        // ────────────────────────────────────────
        // MARK: Здоровье
        // ────────────────────────────────────────

        .init(id: "docplus", displayName: "DocPlus (Док+)",
              aliases: ["док+", "docplus"],
              category: .health,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["health", "telemedicine"]),

        // ────────────────────────────────────────
        // MARK: Еда и доставка
        // ────────────────────────────────────────

        .init(id: "yandex_delivery", displayName: "Яндекс Еда / Лавка",
              aliases: ["яндекс еда", "яндекс лавка", "yandex food"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "yandex"]),

        .init(id: "delivery_club", displayName: "Delivery Club",
              aliases: ["деливери клаб"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery"]),

        // ────────────────────────────────────────
        // MARK: Игры
        // ────────────────────────────────────────

        .init(id: "vk_play", displayName: "VK Play",
              aliases: ["вк плей"],
              category: .games,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["gaming", "vk"]),
    ]
}
