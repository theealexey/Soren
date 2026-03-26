import SwiftUI

// MARK: - Theme Preview

/// Visual showcase of all design tokens.
/// Run this preview to verify light/dark parity.
struct ThemePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                colorsSection
                typographySection
                spacingSection
                chartColorsSection
                categoryColorsSection
            }
            .padding(Spacing.lg)
        }
        .background(ColorTokens.background)
    }

    // MARK: - Colors

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("COLORS")
                .overlineStyle()

            colorRow("Background", ColorTokens.background)
            colorRow("Background Secondary", ColorTokens.backgroundSecondary)
            colorRow("Surface", ColorTokens.surface)
            colorRow("Surface Elevated", ColorTokens.surfaceElevated)
            colorRow("Separator", ColorTokens.separator)
            colorRow("Accent", ColorTokens.accent)
            colorRow("Success", ColorTokens.success)
            colorRow("Warning", ColorTokens.warning)
            colorRow("Error", ColorTokens.error)
            colorRow("Info", ColorTokens.info)
        }
    }

    // MARK: - Typography

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TYPOGRAPHY")
                .overlineStyle()

            Text("$1,247.99")
                .font(Typography.heroAmount)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("$249.50")
                .font(Typography.amountLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("$12.99/mo")
                .font(Typography.amountMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("USD")
                .font(Typography.amountSmall)
                .foregroundStyle(ColorTokens.textSecondary)

            Text("Screen Title")
                .font(Typography.title)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Section Header")
                .font(Typography.sectionHeader)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Item Headline")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text("Body text for descriptions and explanations.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)

            Text("Caption: Next charge Feb 14")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Text("OVERLINE LABEL")
                .overlineStyle()
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SPACING")
                .overlineStyle()

            spacingRow("xxxs", Spacing.xxxs)
            spacingRow("xxs", Spacing.xxs)
            spacingRow("xs", Spacing.xs)
            spacingRow("sm", Spacing.sm)
            spacingRow("md", Spacing.md)
            spacingRow("lg", Spacing.lg)
            spacingRow("xl", Spacing.xl)
            spacingRow("xxl", Spacing.xxl)
        }
    }

    // MARK: - Chart Colors

    private var chartColorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CHART PALETTE")
                .overlineStyle()

            HStack(spacing: Spacing.xxs) {
                ForEach(0..<ColorTokens.chartPalette.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(ColorTokens.chartPalette[index])
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Category Colors

    private var categoryColorsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("CATEGORIES")
                .overlineStyle()

            let categories: [(String, Color)] = [
                ("Video", ColorTokens.categoryVideo),
                ("Music", ColorTokens.categoryMusic),
                ("Cloud", ColorTokens.categoryCloud),
                ("Productivity", ColorTokens.categoryProductivity),
                ("AI", ColorTokens.categoryAI),
                ("Shopping", ColorTokens.categoryShopping),
                ("Banking", ColorTokens.categoryBanking),
                ("Mobile", ColorTokens.categoryMobile),
                ("Health", ColorTokens.categoryHealth),
                ("Games", ColorTokens.categoryGames),
            ]

            FlowLayout(spacing: Spacing.xs) {
                ForEach(categories, id: \.0) { name, color in
                    Text(name)
                        .font(Typography.captionMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, Spacing.xxs)
                        .background(color, in: Capsule())
                }
            }
        }
    }

    // MARK: - Helpers

    private func colorRow(_ name: String, _ color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .strokeBorder(ColorTokens.separator, lineWidth: 0.5)
                )

            Text(name)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: Spacing.sm) {
            Text("\(name) (\(Int(value))pt)")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 100, alignment: .trailing)

            Rectangle()
                .fill(ColorTokens.accent)
                .frame(width: value * 4, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
    }
}

// MARK: - Previews

#Preview("Light") {
    ThemePreview()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ThemePreview()
        .preferredColorScheme(.dark)
}
