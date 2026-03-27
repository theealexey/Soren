import SwiftUI

/// High-level category for grouping and filtering recurring items.
/// Drives icon color in the UI and chart segmentation in Analytics.
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
        case .other:        "Другое"
        }
    }

    var systemIconName: String {
        switch self {
        case .video:        "play.rectangle.fill"
        case .music:        "music.note"
        case .books:        "books.vertical.fill"
        case .cloud:        "cloud.fill"
        case .productivity: "doc.text.fill"
        case .aiTools:      "cpu.fill"
        case .shopping:     "bag.fill"
        case .banking:      "building.columns.fill"
        case .mobile:       "iphone"
        case .internet:     "wifi"
        case .health:       "heart.fill"
        case .games:        "gamecontroller.fill"
        case .vpn:          "lock.shield.fill"
        case .food:         "fork.knife"
        case .education:    "graduationcap.fill"
        case .other:        "ellipsis.circle.fill"
        }
    }

    /// Matches the category color tokens from the Design System.
    var color: Color {
        switch self {
        case .video:        ColorTokens.categoryVideo
        case .music:        ColorTokens.categoryMusic
        case .books:        ColorTokens.categoryMusic
        case .cloud:        ColorTokens.categoryCloud
        case .productivity: ColorTokens.categoryProductivity
        case .aiTools:      ColorTokens.categoryAI
        case .shopping:     ColorTokens.categoryShopping
        case .banking:      ColorTokens.categoryBanking
        case .mobile:       ColorTokens.categoryMobile
        case .internet:     ColorTokens.categoryCloud
        case .health:       ColorTokens.categoryHealth
        case .games:        ColorTokens.categoryGames
        case .vpn:          ColorTokens.categoryProductivity
        case .food:         ColorTokens.categoryShopping
        case .education:    ColorTokens.categoryAI
        case .other:        ColorTokens.textTertiary
        }
    }
}
