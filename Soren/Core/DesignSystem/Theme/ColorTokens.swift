import SwiftUI

// MARK: - Semantic Color Tokens

/// Type-safe access to the app's color palette.
/// All colors are defined in Assets.xcassets/Colors with light + dark variants.
enum ColorTokens {

    // MARK: Backgrounds

    static let background          = Color("Colors/Background")
    static let backgroundSecondary = Color("Colors/BackgroundSecondary")
    static let surface             = Color("Colors/Surface")
    static let surfaceElevated     = Color("Colors/SurfaceElevated")

    // MARK: Text

    static let textPrimary   = Color("Colors/TextPrimary")
    static let textSecondary = Color("Colors/TextSecondary")
    static let textTertiary  = Color("Colors/TextTertiary")

    // MARK: Separator

    static let separator = Color("Colors/Separator")

    // MARK: Accent

    static let accent = Color("Colors/Accent")

    // MARK: Semantic

    static let success = Color("Colors/Success")
    static let warning = Color("Colors/Warning")
    static let error   = Color("Colors/Error")
    static let info    = Color("Colors/Info")

    // MARK: Chart Palette

    static let chartPalette: [Color] = [
        Color("Colors/ChartBlue"),
        Color("Colors/ChartOrange"),
        Color("Colors/ChartPurple"),
        Color("Colors/ChartTeal"),
        Color("Colors/ChartPink"),
        Color("Colors/ChartYellow"),
    ]

    // MARK: Category Colors

    static let categoryVideo        = Color("Colors/CategoryVideo")
    static let categoryMusic        = Color("Colors/CategoryMusic")
    static let categoryCloud        = Color("Colors/CategoryCloud")
    static let categoryProductivity = Color("Colors/CategoryProductivity")
    static let categoryAI           = Color("Colors/CategoryAI")
    static let categoryShopping     = Color("Colors/CategoryShopping")
    static let categoryBanking      = Color("Colors/CategoryBanking")
    static let categoryMobile       = Color("Colors/CategoryMobile")
    static let categoryHealth       = Color("Colors/CategoryHealth")
    static let categoryDating       = Color("Colors/CategoryDating")
    static let categoryGames        = Color("Colors/CategoryGames")
}
