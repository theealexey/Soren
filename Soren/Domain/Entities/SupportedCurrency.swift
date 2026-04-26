import Foundation

// MARK: - Supported Currency

/// Centralized currency metadata — single source of truth.
/// Used in Settings, Add Subscription, Item Edit forms.
///
/// `name` is the ISO-standard English name and serves as a locale-neutral
/// identifier and fallback. For display in the UI use `localizedName`
/// (defined in Core/Extensions/SupportedCurrency+Display.swift).
struct SupportedCurrency: Identifiable, Hashable, Sendable {
    let code: String         // ISO 4217
    let symbol: String
    let name: String         // English — locale-neutral, not a localized string
    let decimalPlaces: Int

    var id: String { code }

    // MARK: - Catalog

    static let all: [SupportedCurrency] = [
        .init(code: "RUB", symbol: "₽",   name: "Russian Ruble",      decimalPlaces: 2),
        .init(code: "USD", symbol: "$",    name: "US Dollar",          decimalPlaces: 2),
        .init(code: "EUR", symbol: "€",    name: "Euro",               decimalPlaces: 2),
        .init(code: "GBP", symbol: "£",    name: "British Pound",      decimalPlaces: 2),
        .init(code: "TRY", symbol: "₺",    name: "Turkish Lira",       decimalPlaces: 2),
        .init(code: "KZT", symbol: "₸",    name: "Kazakhstani Tenge",  decimalPlaces: 2),
        .init(code: "BYN", symbol: "Br",   name: "Belarusian Ruble",   decimalPlaces: 2),
        .init(code: "GEL", symbol: "₾",    name: "Georgian Lari",      decimalPlaces: 2),
        .init(code: "AMD", symbol: "֏",    name: "Armenian Dram",      decimalPlaces: 2),
        .init(code: "AED", symbol: "د.إ",  name: "UAE Dirham",         decimalPlaces: 2),
        .init(code: "JPY", symbol: "¥",    name: "Japanese Yen",       decimalPlaces: 0),
        .init(code: "CNY", symbol: "¥",    name: "Chinese Yuan",       decimalPlaces: 2),
    ]

    static let codes: [String] = all.map(\.code)
}
