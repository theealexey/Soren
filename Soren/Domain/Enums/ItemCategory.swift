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
        case .video:        "Видео"
        case .music:        "Музыка"
        case .books:        "Книги"
        case .cloud:        "Облако"
        case .productivity: "Продуктивность"
        case .aiTools:      "AI-инструменты"
        case .shopping:     "Покупки"
        case .banking:      "Банки и экосистемы"
        case .mobile:       "Мобильный"
        case .internet:     "Интернет и ЖКХ"
        case .health:       "Здоровье"
        case .games:        "Игры"
        case .vpn:          "VPN и безопасность"
        case .food:         "Еда и доставка"
        case .education:    "Образование"
        case .creators:     "Креаторы и донаты"
        case .other:        "Другое"
        }
    }
}
