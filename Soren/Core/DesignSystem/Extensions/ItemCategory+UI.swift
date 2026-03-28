import SwiftUI

// MARK: - Item Category UI Properties

/// Presentation-layer extension mapping domain categories to visual tokens.
/// Keeps the Domain layer free of SwiftUI dependencies.
extension ItemCategory {

    /// SF Symbol name for this category.
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

    /// Design system color token for this category.
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
