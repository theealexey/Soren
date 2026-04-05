import SwiftUI

// MARK: - Insight Row View

/// Single flat insight row: label / value / optional amount.
/// `valueRole` resolves to a theme color — no raw Color values here.
struct InsightRowView: View {

    let model: InsightRowModel

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(model.label)
                .font(Typography.caption)
                .foregroundStyle(theme.secondaryText)

            Spacer()

            Text(model.value)
                .font(Typography.caption)
                .foregroundStyle(valueColor)

            if let amount = model.amount {
                Text(amount)
                    .font(Typography.amountSmall)
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.lg)
    }

    private var valueColor: Color {
        switch model.valueRole {
        case .standard: theme.secondaryText
        case .warning:  theme.warningTint
        case .quiet:    theme.quietTint
        }
    }
}
