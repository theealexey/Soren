import SwiftUI

// MARK: - Typography Scale

/// Consistent type scale across the app.
/// Uses SF Pro (system default) with intentional size/weight pairings.
/// Each style has a clear purpose — no two styles should compete for the same role.
enum Typography {

    // MARK: - Display

    /// Large hero numbers: monthly total, yearly projection.
    /// 34pt light monospaced — clinical data readout, not a marketing headline.
    static let heroAmount = Font.system(size: 34, weight: .light, design: .monospaced)

    /// Section-level financial figures: stat blocks, card amounts.
    /// 24pt regular monospaced — precise and calm.
    static let amountLarge = Font.system(size: 24, weight: .regular, design: .monospaced)

    /// Inline amounts in lists, detail rows.
    /// 17pt regular monospaced — fixed-width prevents layout shifts during updates.
    static let amountMedium = Font.system(size: 17, weight: .regular, design: .monospaced)

    /// Small amounts: secondary info, currency codes.
    static let amountSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: - Headings

    /// Screen titles in navigation bars (handled by system).
    /// Use `.navigationTitle()` — this is for custom headers.
    static let title = Font.system(size: 22, weight: .light)

    /// Section headers inside screens.
    static let sectionHeader = Font.system(size: 15, weight: .semibold)

    /// Card titles, item names in lists.
    static let headline = Font.system(size: 17, weight: .semibold)

    // MARK: - Body

    /// Primary readable text.
    static let body = Font.system(size: 15, weight: .regular)

    /// Emphasized body text.
    static let bodyMedium = Font.system(size: 15, weight: .medium)

    // MARK: - Supporting

    /// Secondary labels, dates, supplementary info.
    static let caption = Font.system(size: 13, weight: .regular)

    /// Emphasized captions: filter chips, tags, badges.
    static let captionMedium = Font.system(size: 13, weight: .medium)

    /// Smallest text: timestamps, disclaimers, footnotes.
    static let footnote = Font.system(size: 11, weight: .regular)

    /// Overline labels above sections: "UPCOMING", "ACTIVE TRIALS".
    /// Semibold + uppercase + wide tracking = airport gate / wayfinding signage.
    static let overline = Font.system(size: 11, weight: .semibold)

    // MARK: - Chart

    /// Axis tick labels on mini charts and the Billing Landscape.
    /// Monospaced digits prevent layout shifts as numbers change.
    static let axisLabel = Font.system(size: 10, design: .monospaced)

    // MARK: - Specialized

    /// Large icon in empty/error state screens.
    static let emptyStateIcon = Font.system(size: 44, weight: .light)

    /// Empty state amount display (search "no results" icon).
    static let emptyStateAmount = Font.system(size: 36, weight: .light)

    /// Icon inside InsightCard / alert cards.
    static let cardIcon = Font.system(size: 18, weight: .semibold)

    /// Disclosure chevron in cards.
    static let chevron = Font.system(size: 12, weight: .semibold)

    /// Tiny trend arrow in TrendBadge.
    static let trendBadge = Font.system(size: 9, weight: .bold)
}

// MARK: - View Modifier for Overline Style

extension View {
    /// Applies overline styling: uppercased via font + letter spacing.
    func overlineStyle() -> some View {
        self
            .font(Typography.overline)
            .textCase(.uppercase)
            .tracking(1.6)
            .foregroundStyle(ColorTokens.textSecondary)
    }
}
