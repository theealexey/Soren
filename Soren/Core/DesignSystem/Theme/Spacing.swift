import SwiftUI

// MARK: - Spacing Scale

/// 4pt grid spacing system.
/// Every dimension in the app should be a multiple of 4 for visual harmony.
enum Spacing {
    /// 2pt — hairline gaps, icon-to-text micro spacing.
    static let xxxs: CGFloat = 2

    /// 4pt — tight inner padding, between badge elements.
    static let xxs: CGFloat = 4

    /// 8pt — compact padding, list item internal gaps.
    static let xs: CGFloat = 8

    /// 12pt — standard gap between related elements.
    static let sm: CGFloat = 12

    /// 16pt — default content padding, card internal margin.
    static let md: CGFloat = 16

    /// 20pt — screen edge padding, section spacing.
    static let lg: CGFloat = 20

    /// 24pt — generous spacing between sections.
    static let xl: CGFloat = 24

    /// 32pt — major section dividers, header-to-content gaps.
    static let xxl: CGFloat = 32

    /// 40pt — screen top/bottom breathing room.
    static let xxxl: CGFloat = 40
}

// MARK: - Corner Radius

/// Consistent corner radius tokens.
enum CornerRadius {
    /// 6pt — small elements: tags, badges, small buttons.
    static let small: CGFloat = 6

    /// 10pt — inputs, chips, inline cards.
    static let medium: CGFloat = 10

    /// 14pt — standard cards, sheets.
    static let large: CGFloat = 14

    /// 20pt — hero cards, modal sheets.
    static let extraLarge: CGFloat = 20
}
