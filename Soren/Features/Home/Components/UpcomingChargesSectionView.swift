import SwiftUI

struct UpcomingChargesSectionView: View {
    let presentation: UpcomingChargesPresentation
    let onSelectItem: (RecurringItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Ближайшие списания"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            rows
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            if presentation.rows.isEmpty {
                Text(String(localized: "Нет ближайших списаний"))
                    .font(.subheadline)
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .padding(.horizontal, 16)
            } else {
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
                            .padding(.leading, 74)
                            .padding(.trailing, 16)
                    }
                }
            }
        }
        .modifier(OverviewGlassSurface(cornerRadius: 24, opaqueColor: SoftClubColor.surface))
    }
}

private struct UpcomingChargeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .subheadline) private var dateSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var amountSize: CGFloat = 17

    let presentation: UpcomingChargePresentation

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                normalLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var normalLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            artwork
            providerIdentity
            amount
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                artwork
                providerIdentity
            }

            amount
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let provider = presentation.item.providerTemplate {
            ProviderIcon(provider: provider, size: .overview)
                .environment(
                    \.colorScheme,
                    presentation.item.providerID == "github_copilot" ? .light : colorScheme
                )
        } else {
            ProviderIcon(category: presentation.item.category, size: .overview)
        }
    }

    private var providerIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: presentation.providerName)
                .font(.system(size: titleSize, weight: .medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: presentation.chargeDate)
                .font(.system(size: dateSize))
                .foregroundStyle(SoftClubColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amount: some View {
        Text(verbatim: presentation.amount)
            .font(.system(size: amountSize, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(SoftClubColor.textPrimary)
            .fixedSize(horizontal: true, vertical: false)
    }
}
