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
            Text(verbatim: "COLORS")
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
            Text(verbatim: "TYPOGRAPHY")
                .overlineStyle()

            Text(verbatim: "1 247,99 ₽")
                .font(Typography.heroAmount)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "249,50 ₽")
                .font(Typography.amountLarge)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "12,99 ₽/мес")
                .font(Typography.amountMedium)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "RUB")
                .font(Typography.amountSmall)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(verbatim: "Заголовок экрана")
                .font(Typography.title)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "Заголовок раздела")
                .font(Typography.sectionHeader)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "Заголовок элемента")
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)

            Text(verbatim: "Основной текст для описаний и пояснений.")
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)

            Text(verbatim: "Подпись: следующее списание 14 февр.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)

            Text(verbatim: "ОВЕРЛАЙН МЕТКА")
                .overlineStyle()
        }
    }

    // MARK: - Spacing

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(verbatim: "SPACING")
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
            Text(verbatim: "CHART PALETTE")
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
            Text(verbatim: "CATEGORIES")
                .overlineStyle()

            let categories: [(String, Color)] = [
                ("Видео", ColorTokens.categoryVideo),
                ("Музыка", ColorTokens.categoryMusic),
                ("Облако", ColorTokens.categoryCloud),
                ("Продуктивность", ColorTokens.categoryProductivity),
                ("AI", ColorTokens.categoryAI),
                ("Покупки", ColorTokens.categoryShopping),
                ("Банки", ColorTokens.categoryBanking),
                ("Мобильный", ColorTokens.categoryMobile),
                ("Здоровье", ColorTokens.categoryHealth),
                ("Игры", ColorTokens.categoryGames),
            ]

            FlowLayout(spacing: Spacing.xs) {
                ForEach(categories, id: \.0) { name, color in
                    Text(verbatim: name)
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

            Text(verbatim: name)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textPrimary)
        }
    }

    private func spacingRow(_ name: String, _ value: CGFloat) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(verbatim: "\(name) (\(Int(value))pt)")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 100, alignment: .trailing)

            Rectangle()
                .fill(ColorTokens.accent)
                .frame(width: value * 4, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.hairline))
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
