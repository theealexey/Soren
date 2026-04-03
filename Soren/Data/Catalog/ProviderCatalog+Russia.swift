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
              tags: ["ecosystem", "bundle", "cashback", "popular"],
              brandColorHex: "#FC3F1D", clearbitDomain: "yandex.ru",
              plans: [
                  .init(id: "basic", name: "Базовый", amount: 199, billingCycle: .monthly, features: "Кешбэк, Музыка"),
                  .init(id: "standard", name: "Стандарт", amount: 399, billingCycle: .monthly, features: "Кешбэк, Музыка, Кинопоиск"),
                  .init(id: "family", name: "Семейный", amount: 599, billingCycle: .monthly, features: "До 4 участников"),
              ]),

        .init(id: "sber_prime", displayName: "СберПрайм+",
              aliases: ["сбер прайм", "sberprime", "sber"],
              category: .banking, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "banking", "bundle"],
              brandColorHex: "#21A038", clearbitDomain: "sber.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 399, billingCycle: .monthly, features: "Кешбэк, Звук, Okko"),
                  .init(id: "prime_plus", name: "Прайм+", amount: 599, billingCycle: .monthly, features: "Всё + повышенный кешбэк"),
              ]),

        .init(id: "mts_premium", displayName: "МТС Premium",
              aliases: ["мтс премиум", "mts premium"],
              category: .mobile, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "telecom", "bundle", "popular"],
              brandColorHex: "#E30611", clearbitDomain: "mts.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 199, billingCycle: .monthly, features: "KION, музыка, кешбэк"),
                  .init(id: "family", name: "Семейный", amount: 349, billingCycle: .monthly, features: "До 5 участников"),
              ]),

        .init(id: "tbank_pro", displayName: "Т-Банк Pro",
              aliases: ["т-банк", "tinkoff pro", "тинькофф про", "t-bank"],
              category: .banking, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["banking", "cashback"],
              brandColorHex: "#FFDD2D", clearbitDomain: "tbank.ru"),

        // ────────────────────────────────────────
        // MARK: Видео
        // ────────────────────────────────────────

        .init(id: "kinopoisk", displayName: "Кинопоиск",
              aliases: ["кп", "kinopoisk"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "yandex"],
              brandColorHex: "#FF5500", clearbitDomain: "kinopoisk.ru"),

        .init(id: "okko", displayName: "Okko",
              aliases: ["окко"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#A033FF", clearbitDomain: "okko.tv"),

        .init(id: "wink", displayName: "Wink",
              aliases: ["винк"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "rostelecom"],
              brandColorHex: "#7B2BFC", clearbitDomain: "wink.ru"),

        .init(id: "kion", displayName: "KION",
              aliases: ["кион"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "mts"],
              brandColorHex: "#E30611", clearbitDomain: "kion.ru"),

        .init(id: "start", displayName: "START",
              aliases: ["старт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#F43B3B", clearbitDomain: "start.ru"),

        .init(id: "premier", displayName: "PREMIER",
              aliases: ["премьер", "тнт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#FF1F8E", clearbitDomain: "premier.one"),

        .init(id: "ivi", displayName: "IVI",
              aliases: ["иви"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#EA003D", clearbitDomain: "ivi.ru"),

        // ────────────────────────────────────────
        // MARK: Музыка
        // ────────────────────────────────────────

        .init(id: "yandex_music", displayName: "Яндекс Музыка",
              aliases: ["яндекс музыка", "yandex music"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "yandex"],
              brandColorHex: "#FFDB4D", clearbitDomain: "music.yandex.ru"),

        .init(id: "zvuk", displayName: "Звук",
              aliases: ["zvuk", "сбер звук"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "sber"],
              brandColorHex: "#0DC268", clearbitDomain: "zvuk.com"),

        .init(id: "vk_music", displayName: "VK Музыка",
              aliases: ["вк музыка", "vk music", "boom"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "vk"],
              brandColorHex: "#0077FF", clearbitDomain: "vk.com"),

        // ────────────────────────────────────────
        // MARK: Маркетплейсы
        // ────────────────────────────────────────

        .init(id: "ozon_premium", displayName: "Ozon Premium",
              aliases: ["озон", "ozon"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "delivery"],
              brandColorHex: "#005BFF", clearbitDomain: "ozon.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 199, billingCycle: .monthly, features: "Бесплатная доставка, баллы"),
              ]),

        .init(id: "wb_club", displayName: "WB Клуб",
              aliases: ["вайлдберриз", "wildberries", "wb"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace"],
              brandColorHex: "#CB11AB", clearbitDomain: "wildberries.ru"),

        .init(id: "yandex_market_plus", displayName: "Яндекс Маркет Плюс",
              aliases: ["яндекс маркет", "yandex market"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "yandex"],
              brandColorHex: "#FC3F1D", clearbitDomain: "market.yandex.ru"),

        .init(id: "samokat", displayName: "Самокат Плюс",
              aliases: ["samokat"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "grocery"],
              brandColorHex: "#FF3366", clearbitDomain: "samokat.ru"),

        // ────────────────────────────────────────
        // MARK: Мобильные операторы
        // ────────────────────────────────────────

        .init(id: "mts", displayName: "МТС",
              aliases: ["mts"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#E30611", clearbitDomain: "mts.ru"),

        .init(id: "megafon", displayName: "МегаФон",
              aliases: ["мегафон", "megafon"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#00B956", clearbitDomain: "megafon.ru"),

        .init(id: "beeline", displayName: "Билайн",
              aliases: ["beeline", "билайн"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#FFCE00", clearbitDomain: "beeline.ru"),

        .init(id: "t2", displayName: "Т2 (Tele2)",
              aliases: ["tele2", "теле2", "т2"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#1F2229", clearbitDomain: "tele2.ru"),

        .init(id: "yota", displayName: "Yota",
              aliases: ["йота"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#00B4EF", clearbitDomain: "yota.ru"),

        // ────────────────────────────────────────
        // MARK: Облако
        // ────────────────────────────────────────

        .init(id: "yandex_disk", displayName: "Яндекс Диск",
              aliases: ["яндекс диск", "yandex disk"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "yandex"],
              brandColorHex: "#FC3F1D", clearbitDomain: "disk.yandex.ru"),

        .init(id: "mail_cloud", displayName: "Облако Mail.ru",
              aliases: ["облако mail", "mail cloud", "vk cloud"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "vk"],
              brandColorHex: "#005FF9", clearbitDomain: "mail.ru"),

        // ────────────────────────────────────────
        // MARK: Образование
        // ────────────────────────────────────────

        .init(id: "skillbox", displayName: "Skillbox",
              aliases: ["скиллбокс"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"],
              brandColorHex: "#6B4FBB", clearbitDomain: "skillbox.ru"),

        .init(id: "stepik", displayName: "Stepik",
              aliases: ["степик"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"],
              brandColorHex: "#5AAF4C", clearbitDomain: "stepik.org"),

        .init(id: "practicum", displayName: "Яндекс Практикум",
              aliases: ["практикум", "yandex practicum"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses", "yandex"],
              brandColorHex: "#FC3F1D", clearbitDomain: "practicum.yandex.ru"),

        // ────────────────────────────────────────
        // MARK: Книги
        // ────────────────────────────────────────

        .init(id: "litres", displayName: "ЛитРес",
              aliases: ["litres", "литрес"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books", "audiobooks"],
              brandColorHex: "#FF6600", clearbitDomain: "litres.ru"),

        .init(id: "bookmate", displayName: "Bookmate",
              aliases: ["букмейт"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books"],
              brandColorHex: "#F43B40", clearbitDomain: "bookmate.com"),

        // ────────────────────────────────────────
        // MARK: Здоровье
        // ────────────────────────────────────────

        .init(id: "docplus", displayName: "DocPlus (Док+)",
              aliases: ["док+", "docplus"],
              category: .health,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["health", "telemedicine"],
              brandColorHex: "#00C1B4", clearbitDomain: "docplus.ru"),

        // ────────────────────────────────────────
        // MARK: Еда и доставка
        // ────────────────────────────────────────

        .init(id: "yandex_delivery", displayName: "Яндекс Еда / Лавка",
              aliases: ["яндекс еда", "яндекс лавка", "yandex food"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "yandex"],
              brandColorHex: "#FC3F1D", clearbitDomain: "eda.yandex.ru"),

        .init(id: "delivery_club", displayName: "Delivery Club",
              aliases: ["деливери клаб"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery"],
              brandColorHex: "#2AC96B", clearbitDomain: "delivery-club.ru"),

        // ────────────────────────────────────────
        // MARK: Креаторы и донаты
        // ────────────────────────────────────────

        .init(id: "boosty", displayName: "Boosty",
              aliases: ["бусти"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#F15F2C", clearbitDomain: "boosty.to"),

        .init(id: "donationalerts", displayName: "DonationAlerts",
              aliases: ["донейшн алертс", "da"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#F57B20", clearbitDomain: "donationalerts.com"),

        .init(id: "sponsr", displayName: "Sponsr",
              aliases: ["спонср"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#6C5CE7", clearbitDomain: "sponsr.ru"),

        // ────────────────────────────────────────
        // MARK: Игры
        // ────────────────────────────────────────

        .init(id: "vk_play", displayName: "VK Play",
              aliases: ["вк плей"],
              category: .games,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["gaming", "vk"],
              brandColorHex: "#0077FF", clearbitDomain: "vkplay.ru"),
    ]
}
