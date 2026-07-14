import Foundation

// MARK: - Russian Market Providers
//
// ЦЕНОВАЯ ПОЛИТИКА / PRICING POLICY
// Все суммы — справочные значения для российского рынка на момент составления каталога.
// Реальные цены зависят от акций, региона, даты подписки и изменений тарифов сервисов.
// Пользователь должен проверить и скорректировать сумму после добавления.
//
// All amounts are Russian-market reference values at the time the catalog was authored.
// Actual prices depend on promotions, region, subscription date, and service tariff changes.
// Users are expected to verify and correct the amount after adding a subscription.

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
              brandColorHex: "#FC3F1D", companyLogoFallbackDomain: "yandex.ru",
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
              brandColorHex: "#21A038", companyLogoFallbackDomain: "sber.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 399, billingCycle: .monthly, features: "Кешбэк, Звук, Okko"),
                  .init(id: "prime_plus", name: "Прайм+", amount: 599, billingCycle: .monthly, features: "Всё + повышенный кешбэк"),
              ]),

        .init(id: "mts_premium", displayName: "МТС Premium",
              aliases: ["мтс премиум", "mts premium"],
              category: .mobile, itemType: .ecosystemBundle,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["ecosystem", "telecom", "bundle", "popular"],
              brandColorHex: "#E30611", companyLogoFallbackDomain: "mts.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 199, billingCycle: .monthly, features: "KION, музыка, кешбэк"),
                  .init(id: "family", name: "Семейный", amount: 349, billingCycle: .monthly, features: "До 5 участников"),
              ]),

        .init(id: "tbank_pro", displayName: "Т-Банк Pro",
              aliases: ["т-банк", "tinkoff pro", "тинькофф про", "t-bank"],
              category: .banking, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["banking", "cashback"],
              brandColorHex: "#FFDD2D", companyLogoFallbackDomain: "tbank.ru",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 790, billingCycle: .monthly, features: "Кешбэк до 30%, страховка, консьерж"),
              ]),

        // ────────────────────────────────────────
        // MARK: Видео
        // ────────────────────────────────────────

        .init(id: "kinopoisk", displayName: "Кинопоиск",
              aliases: ["кп", "kinopoisk"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "yandex"],
              brandColorHex: "#FF5500", companyLogoFallbackDomain: "kinopoisk.ru",
              plans: [
                  .init(id: "basic", name: "Базовый", amount: 299, billingCycle: .monthly, features: "FHD, онлайн-просмотр"),
                  .init(id: "optimal", name: "Оптимальный", amount: 399, billingCycle: .monthly, features: "4K HDR, скачивание"),
              ]),

        .init(id: "okko", displayName: "Okko",
              aliases: ["окко"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#A033FF", companyLogoFallbackDomain: "okko.tv",
              plans: [
                  .init(id: "optimal", name: "Оптимальный", amount: 399, billingCycle: .monthly, features: "4K HDR, скачивание"),
              ]),

        .init(id: "wink", displayName: "Wink",
              aliases: ["винк"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "rostelecom"],
              brandColorHex: "#7B2BFC", companyLogoFallbackDomain: "wink.ru",
              plans: [
                  .init(id: "basic", name: "Базовая", amount: 199, billingCycle: .monthly, features: "Фильмы и сериалы"),
              ]),

        .init(id: "kion", displayName: "KION",
              aliases: ["кион"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming", "mts"],
              brandColorHex: "#E30611", companyLogoFallbackDomain: "kion.ru",
              plans: [
                  .init(id: "kion", name: "KION", amount: 299, billingCycle: .monthly, features: "Оригиналы МТС, 4K"),
              ]),

        .init(id: "start", displayName: "START",
              aliases: ["старт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#F43B3B", companyLogoFallbackDomain: "start.ru",
              plans: [
                  .init(id: "start", name: "START", amount: 399, billingCycle: .monthly, features: "Оригинальные сериалы, 4K"),
              ]),

        .init(id: "premier", displayName: "PREMIER",
              aliases: ["премьер", "тнт"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#FF1F8E", companyLogoFallbackDomain: "premier.one",
              plans: [
                  .init(id: "premier", name: "PREMIER", amount: 299, billingCycle: .monthly, features: "ТНТ, ТВ-3, 2×2, оригиналы"),
              ]),

        .init(id: "ivi", displayName: "IVI",
              aliases: ["иви"],
              category: .video,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["streaming"],
              brandColorHex: "#EA003D", companyLogoFallbackDomain: "ivi.ru",
              plans: [
                  .init(id: "ivi", name: "IVI", amount: 299, billingCycle: .monthly, features: "FHD, без рекламы"),
                  .init(id: "ivi_plus", name: "IVI+", amount: 499, billingCycle: .monthly, features: "4K UHD, скачивание"),
              ]),

        // ────────────────────────────────────────
        // MARK: Музыка
        // ────────────────────────────────────────

        .init(id: "yandex_music", displayName: "Яндекс Музыка",
              aliases: ["яндекс музыка", "yandex music"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "yandex"],
              brandColorHex: "#FFDB4D", companyLogoFallbackDomain: "music.yandex.ru",
              plans: [
                  .init(id: "individual", name: "Индивидуальная", amount: 169, billingCycle: .monthly),
                  .init(id: "family", name: "Семейная", amount: 349, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "zvuk", displayName: "Звук",
              aliases: ["zvuk", "сбер звук"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "sber"],
              brandColorHex: "#0DC268", companyLogoFallbackDomain: "zvuk.com",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 169, billingCycle: .monthly),
                  .init(id: "family", name: "Семейный", amount: 349, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        .init(id: "vk_music", displayName: "VK Музыка",
              aliases: ["вк музыка", "vk music", "boom"],
              category: .music,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["music", "vk"],
              brandColorHex: "#0077FF", companyLogoFallbackDomain: "vk.com",
              plans: [
                  .init(id: "individual", name: "Индивидуальная", amount: 169, billingCycle: .monthly),
                  .init(id: "family", name: "Семейная", amount: 299, billingCycle: .monthly, features: "До 6 участников"),
              ]),

        // ────────────────────────────────────────
        // MARK: Маркетплейсы
        // ────────────────────────────────────────

        .init(id: "ozon_premium", displayName: "Ozon Premium",
              aliases: ["озон", "ozon"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "delivery"],
              brandColorHex: "#005BFF", companyLogoFallbackDomain: "ozon.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 199, billingCycle: .monthly, features: "Бесплатная доставка, баллы"),
              ]),

        .init(id: "wb_club", displayName: "WB Клуб",
              aliases: ["вайлдберриз", "wildberries", "wb"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace"],
              brandColorHex: "#CB11AB", companyLogoFallbackDomain: "wildberries.ru",
              plans: [
                  .init(id: "standard", name: "WB Клуб", amount: 349, billingCycle: .monthly, features: "Скидки, бесплатная доставка"),
              ]),

        .init(id: "yandex_market_plus", displayName: "Яндекс Маркет Плюс",
              aliases: ["яндекс маркет", "yandex market"],
              category: .shopping, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["marketplace", "yandex"],
              brandColorHex: "#FC3F1D", companyLogoFallbackDomain: "market.yandex.ru",
              plans: [
                  .init(id: "standard", name: "Маркет Плюс", amount: 199, billingCycle: .monthly, features: "Кешбэк, бесплатная доставка"),
              ]),

        .init(id: "samokat", displayName: "Самокат Плюс",
              aliases: ["samokat"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "grocery"],
              brandColorHex: "#FF3366", companyLogoFallbackDomain: "samokat.ru",
              plans: [
                  .init(id: "plus", name: "Плюс", amount: 199, billingCycle: .monthly, features: "Бесплатная доставка от 499₽"),
              ]),

        // ────────────────────────────────────────
        // MARK: Мобильные операторы
        // ────────────────────────────────────────

        .init(id: "mts", displayName: "МТС",
              aliases: ["mts"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#E30611", companyLogoFallbackDomain: "mts.ru"),

        .init(id: "megafon", displayName: "МегаФон",
              aliases: ["мегафон", "megafon"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#00B956", companyLogoFallbackDomain: "megafon.ru"),

        .init(id: "beeline", displayName: "Билайн",
              aliases: ["beeline", "билайн"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#FFCE00", companyLogoFallbackDomain: "beeline.ru"),

        .init(id: "t2", displayName: "Т2 (Tele2)",
              aliases: ["tele2", "теле2", "т2"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#1F2229", companyLogoFallbackDomain: "tele2.ru"),

        .init(id: "yota", displayName: "Yota",
              aliases: ["йота"],
              category: .mobile, itemType: .mobilePlan,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["telecom"],
              brandColorHex: "#00B4EF", companyLogoFallbackDomain: "yota.ru"),

        // ────────────────────────────────────────
        // MARK: Облако
        // ────────────────────────────────────────

        .init(id: "yandex_disk", displayName: "Яндекс Диск",
              aliases: ["яндекс диск", "yandex disk"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "yandex"],
              brandColorHex: "#FC3F1D", companyLogoFallbackDomain: "disk.yandex.ru",
              plans: [
                  .init(id: "100gb", name: "100 ГБ", amount: 69, billingCycle: .monthly),
                  .init(id: "200gb", name: "200 ГБ", amount: 99, billingCycle: .monthly),
                  .init(id: "500gb", name: "500 ГБ", amount: 149, billingCycle: .monthly),
                  .init(id: "1tb", name: "1 ТБ", amount: 249, billingCycle: .monthly),
                  .init(id: "3tb", name: "3 ТБ", amount: 449, billingCycle: .monthly),
              ]),

        .init(id: "mail_cloud", displayName: "Облако Mail.ru",
              aliases: ["облако mail", "mail cloud", "vk cloud"],
              category: .cloud,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["storage", "vk"],
              brandColorHex: "#005FF9", companyLogoFallbackDomain: "mail.ru",
              plans: [
                  .init(id: "64gb", name: "64 ГБ", amount: 49, billingCycle: .monthly),
                  .init(id: "128gb", name: "128 ГБ", amount: 79, billingCycle: .monthly),
                  .init(id: "256gb", name: "256 ГБ", amount: 149, billingCycle: .monthly),
                  .init(id: "512gb", name: "512 ГБ", amount: 199, billingCycle: .monthly),
                  .init(id: "1tb", name: "1 ТБ", amount: 299, billingCycle: .monthly),
              ]),

        // ────────────────────────────────────────
        // MARK: Образование
        // ────────────────────────────────────────

        .init(id: "skillbox", displayName: "Skillbox",
              aliases: ["скиллбокс"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"],
              brandColorHex: "#6B4FBB", companyLogoFallbackDomain: "skillbox.ru"),

        .init(id: "stepik", displayName: "Stepik",
              aliases: ["степик"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses"],
              brandColorHex: "#5AAF4C", companyLogoFallbackDomain: "stepik.org",
              plans: [
                  .init(id: "pro", name: "Pro", amount: 1299, billingCycle: .monthly, features: "Все курсы без ограничений"),
              ]),

        .init(id: "practicum", displayName: "Яндекс Практикум",
              aliases: ["практикум", "yandex practicum"],
              category: .education,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["courses", "yandex"],
              brandColorHex: "#FC3F1D", companyLogoFallbackDomain: "practicum.yandex.ru"),

        // ────────────────────────────────────────
        // MARK: Книги
        // ────────────────────────────────────────

        .init(id: "litres", displayName: "ЛитРес",
              aliases: ["litres", "литрес"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books", "audiobooks"],
              brandColorHex: "#FF6600", companyLogoFallbackDomain: "litres.ru",
              plans: [
                  .init(id: "standard", name: "Стандарт", amount: 699, billingCycle: .monthly, features: "Книги + аудиокниги"),
                  .init(id: "annual", name: "Годовой", amount: 4999, billingCycle: .annual, features: "Экономия ~3,4K₽"),
              ]),

        .init(id: "bookmate", displayName: "Bookmate",
              aliases: ["букмейт"],
              category: .books,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["books"],
              brandColorHex: "#F43B40", companyLogoFallbackDomain: "bookmate.com",
              plans: [
                  .init(id: "monthly", name: "Ежемесячно", amount: 449, billingCycle: .monthly, features: "Книги, аудио, комиксы"),
                  .init(id: "annual", name: "Годовой", amount: 2499, billingCycle: .annual, features: "Экономия ~2,9K₽"),
              ]),

        // ────────────────────────────────────────
        // MARK: Здоровье
        // ────────────────────────────────────────

        .init(id: "docplus", displayName: "DocPlus (Док+)",
              aliases: ["док+", "docplus"],
              category: .health,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["health", "telemedicine"],
              brandColorHex: "#00C1B4", companyLogoFallbackDomain: "docplus.ru",
              plans: [
                  .init(id: "basic", name: "Базовый", amount: 590, billingCycle: .monthly, features: "3 консультации/мес"),
                  .init(id: "premium", name: "Премиум", amount: 990, billingCycle: .monthly, features: "Безлимитные консультации"),
              ]),

        // ────────────────────────────────────────
        // MARK: Еда и доставка
        // ────────────────────────────────────────

        .init(id: "yandex_delivery", displayName: "Яндекс Еда / Лавка",
              aliases: ["яндекс еда", "яндекс лавка", "yandex food"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery", "yandex"],
              brandColorHex: "#FC3F1D", companyLogoFallbackDomain: "eda.yandex.ru"),

        .init(id: "delivery_club", displayName: "Delivery Club",
              aliases: ["деливери клаб"],
              category: .food, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["delivery"],
              brandColorHex: "#2AC96B", companyLogoFallbackDomain: "delivery-club.ru"),

        // ────────────────────────────────────────
        // MARK: Креаторы и донаты
        // ────────────────────────────────────────

        .init(id: "boosty", displayName: "Boosty",
              aliases: ["бусти"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#F15F2C", companyLogoFallbackDomain: "boosty.to"),

        .init(id: "donationalerts", displayName: "DonationAlerts",
              aliases: ["донейшн алертс", "da"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#F57B20", companyLogoFallbackDomain: "donationalerts.com"),

        .init(id: "sponsr", displayName: "Sponsr",
              aliases: ["спонср"],
              category: .creators, itemType: .membership,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["creators", "donations"],
              brandColorHex: "#6C5CE7", companyLogoFallbackDomain: "sponsr.ru"),

        // ────────────────────────────────────────
        // MARK: Игры
        // ────────────────────────────────────────

        .init(id: "vk_play", displayName: "VK Play",
              aliases: ["вк плей"],
              category: .games,
              suggestedCurrencyCode: "RUB", region: .russia,
              tags: ["gaming", "vk"],
              brandColorHex: "#0077FF", companyLogoFallbackDomain: "vkplay.ru",
              plans: [
                  .init(id: "monthly", name: "Play Pass", amount: 299, billingCycle: .monthly, features: "Каталог игр, без рекламы"),
              ]),
    ]
}
