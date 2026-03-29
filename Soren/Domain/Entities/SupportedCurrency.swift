import Foundation

// MARK: - Supported Currency

/// Centralized currency metadata — single source of truth.
/// Used in Settings, Add Subscription, Item Edit forms.
struct SupportedCurrency: Identifiable, Hashable, Sendable {
    let code: String         // ISO 4217
    let symbol: String
    let name: String
    let decimalPlaces: Int

    var id: String { code }

    // MARK: - Catalog

    static let all: [SupportedCurrency] = [
        .init(code: "RUB", symbol: "₽",   name: String(localized: "Российский рубль"),   decimalPlaces: 2),
        .init(code: "USD", symbol: "$",    name: String(localized: "Доллар США"),          decimalPlaces: 2),
        .init(code: "EUR", symbol: "€",    name: String(localized: "Евро"),                decimalPlaces: 2),
        .init(code: "GBP", symbol: "£",    name: String(localized: "Фунт стерлингов"),     decimalPlaces: 2),
        .init(code: "TRY", symbol: "₺",    name: String(localized: "Турецкая лира"),       decimalPlaces: 2),
        .init(code: "KZT", symbol: "₸",    name: String(localized: "Казахстанский тенге"), decimalPlaces: 2),
        .init(code: "BYN", symbol: "Br",   name: String(localized: "Белорусский рубль"),   decimalPlaces: 2),
        .init(code: "GEL", symbol: "₾",    name: String(localized: "Грузинский лари"),     decimalPlaces: 2),
        .init(code: "AMD", symbol: "֏",    name: String(localized: "Армянский драм"),      decimalPlaces: 2),
        .init(code: "AED", symbol: "د.إ",  name: String(localized: "Дирхам ОАЭ"),         decimalPlaces: 2),
        .init(code: "JPY", symbol: "¥",    name: String(localized: "Японская иена"),       decimalPlaces: 0),
        .init(code: "CNY", symbol: "¥",    name: String(localized: "Кита��ский юань"),      decimalPlaces: 2),
    ]

    static let codes: [String] = all.map(\.code)
}
