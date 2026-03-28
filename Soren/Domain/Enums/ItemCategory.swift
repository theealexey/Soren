import Foundation

/// High-level category for grouping and filtering recurring items.
/// UI-specific properties (icon, color) live in Core/DesignSystem/Extensions/ItemCategory+UI.swift.
enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case video
    case music
    case books
    case cloud
    case productivity
    case aiTools
    case shopping
    case banking
    case mobile
    case internet
    case health
    case games
    case vpn
    case food
    case education
    case creators
    case other
}

extension ItemCategory {
    var displayName: String {
        switch self {
        case .video:        String(localized: "Видео")
        case .music:        String(localized: "Музыка")
        case .books:        String(localized: "Книги")
        case .cloud:        String(localized: "Облако")
        case .productivity: String(localized: "Продуктивность")
        case .aiTools:      String(localized: "AI-инструменты")
        case .shopping:     String(localized: "Покупки")
        case .banking:      String(localized: "Банки и экосистемы")
        case .mobile:       String(localized: "Мобильный")
        case .internet:     String(localized: "Интернет и ЖКХ")
        case .health:       String(localized: "Здоровье")
        case .games:        String(localized: "Игры")
        case .vpn:          String(localized: "VPN и безопасность")
        case .food:         String(localized: "Еда и доставка")
        case .education:    String(localized: "Образование")
        case .creators:     String(localized: "Креаторы и донаты")
        case .other:        String(localized: "Другое")
        }
    }
}
