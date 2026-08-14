import SwiftUI

struct UpcomingChargesSectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: UpcomingChargesPresentation
    let onSelectItem: (RecurringItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if presentation.rows.isEmpty {
                Text(verbatim: presentation.emptyMessage)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .padding(.vertical, 4)
                    .accessibilityLabel(presentation.emptyMessage)
            } else {
                rows
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                title
                metadata
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                title
                Spacer(minLength: 8)
                metadata
            }
        }
    }

    private var title: some View {
        Text(String(localized: "Ближайшие списания"))
            .font(titleFont)
            .foregroundStyle(SoftClubColor.textPrimary)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var metadata: some View {
        if let metadata = presentation.aggregateMetadata {
            if dynamicTypeSize.isAccessibilitySize {
                Text(verbatim: metadata)
                    .font(.system(size: OverviewAccessibilityTypeScale.size(
                        for: dynamicTypeSize,
                        accessibility1: 15,
                        accessibility3: 17,
                        accessibility5: 19
                    )))
                    .foregroundStyle(SoftClubColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(verbatim: metadata)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(SoftClubColor.textTertiary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private var titleFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 19, weight: .semibold)
        }
        return .system(
            size: OverviewAccessibilityTypeScale.size(
                for: dynamicTypeSize,
                accessibility1: 21,
                accessibility3: 23,
                accessibility5: 25
            ),
            weight: .semibold
        )
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(presentation.rows.enumerated()), id: \.element.id) { index, row in
                Button {
                    onSelectItem(row.item)
                } label: {
                    UpcomingChargeRow(presentation: row)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < presentation.rows.count - 1 {
                    Rectangle()
                        .fill(SoftClubColor.subtleSeparator)
                        .frame(height: 0.5)
                        .opacity(0.72)
                        .padding(.leading, 54)
                        .padding(.trailing, 14)
                }
            }
        }
        .modifier(OverviewAcrylicSurface(role: .upcoming))
    }
}

private struct UpcomingChargeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: UpcomingChargePresentation

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                normalLayout
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : 9)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var normalLayout: some View {
        HStack(alignment: .center, spacing: 11) {
            artwork
            providerIdentity
            Spacer(minLength: 8)
            amountAndDate
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 11) {
                artwork
                providerIdentity
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    amount
                    Spacer(minLength: 12)
                    chargeDate
                }

                VStack(alignment: .leading, spacing: 2) {
                    amount
                    chargeDate
                }
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let provider = presentation.item.providerTemplate {
            ProviderIcon(provider: provider, size: .medium)
                .scaleEffect(presentation.artworkScale)
                .frame(width: 40, height: 40)
        } else {
            ProviderIcon(category: presentation.item.category, size: .medium)
                .frame(width: 40, height: 40)
        }
    }

    private var providerIdentity: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: presentation.providerName)
                .font(providerFont)
                .foregroundStyle(SoftClubColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            Text(verbatim: presentation.planOrCycle)
                .font(secondaryFont)
                .foregroundStyle(SoftClubColor.textSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amountAndDate: some View {
        VStack(alignment: .trailing, spacing: 2) {
            amount
            chargeDate
        }
    }

    private var amount: some View {
        Text(verbatim: presentation.amount)
            .font(providerFont)
            .monospacedDigit()
            .foregroundStyle(SoftClubColor.textPrimary)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var chargeDate: some View {
        Text(verbatim: presentation.chargeDate)
            .font(secondaryFont)
            .foregroundStyle(SoftClubColor.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var providerFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 17, weight: .medium)
        }
        return .system(
            size: OverviewAccessibilityTypeScale.size(
                for: dynamicTypeSize,
                accessibility1: 18,
                accessibility3: 20,
                accessibility5: 22
            ),
            weight: .medium
        )
    }

    private var secondaryFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: 14, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 15,
            accessibility3: 17,
            accessibility5: 19
        ))
    }
}
