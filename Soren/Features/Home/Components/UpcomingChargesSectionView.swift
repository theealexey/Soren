import SwiftUI

struct UpcomingChargesSectionView: View {
    let presentation: UpcomingChargesPresentation
    let onSelectItem: (RecurringItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Ближайшие списания"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            rows
        }
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
                        .fill(SoftClubColor.subtleSeparator.opacity(0.68))
                        .frame(height: 0.5)
                        .padding(.leading, 68)
                        .padding(.trailing, 16)
                }
            }
        }
        .modifier(OverviewAcrylicSurface(role: .upcoming))
    }
}

private struct UpcomingChargeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

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
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var normalLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
                .padding(.top, 1)
            providerIdentity

            amount
                .padding(.top, 1)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                artwork
                    .padding(.top, 1)
                providerIdentity
            }

            amount
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let provider = presentation.item.providerTemplate {
            ProviderIcon(provider: provider, size: .medium)
                .environment(
                    \.colorScheme,
                    presentation.item.providerID == "github_copilot" ? .light : colorScheme
                )
        } else {
            ProviderIcon(category: presentation.item.category, size: .medium)
        }
    }

    private var providerIdentity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: presentation.providerName)
                .font(.body.weight(.medium))
                .foregroundStyle(SoftClubColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(verbatim: presentation.chargeDate)
                .font(.footnote)
                .foregroundStyle(SoftClubColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var amount: some View {
        Text(verbatim: presentation.amount)
            .font(.body.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(SoftClubColor.textPrimary)
            .fixedSize(horizontal: true, vertical: false)
    }
}
