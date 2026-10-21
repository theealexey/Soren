import SwiftUI

struct CalendarAgendaView: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let occurrences: [CalendarScheduleOccurrence]
    let openItem: (RecurringItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(occurrences.enumerated()), id: \.offset) { index, occurrence in
                Button { openItem(occurrence.item) } label: {
                    CalendarAgendaRow(occurrence: occurrence)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                if index < occurrences.count - 1 {
                    Rectangle()
                        .fill(SoftClubColor.subtleSeparator)
                        .frame(height: contrast == .increased ? 1 : 0.5)
                        .padding(.leading, 62)
                }
            }
        }
        .background(SoftClubColor.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(SoftClubColor.subtleBorder, lineWidth: 1)
            }
        }
    }
}

private struct CalendarAgendaRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize = 16.0
    @ScaledMetric(relativeTo: .subheadline) private var metadataSize = 13.0
    @ScaledMetric(relativeTo: .headline) private var amountSize = 16.0
    let occurrence: CalendarScheduleOccurrence

    var body: some View {
        HStack(alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center, spacing: 12) {
            icon
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    labels
                    amount
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                labels.frame(maxWidth: .infinity, alignment: .leading)
                amount.fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 68)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        Group {
            if let provider = occurrence.item.providerTemplate {
                ProviderIcon(provider: provider, size: .medium)
            } else {
                ProviderIcon(category: occurrence.item.category, size: .medium)
            }
        }
        .scaleEffect(0.9)
        .frame(width: 36, height: 36)
        .accessibilityHidden(true)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(occurrence.item.title)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(SoftClubColor.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            Text(CalendarPresentation.metadata(for: occurrence))
                .font(.system(size: metadataSize, weight: .regular))
                .foregroundStyle(SoftClubColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var amount: some View {
        if let money = occurrence.money {
            Text(AmountLabel(money.amount, currency: money.currencyCode).formattedAmount)
                .font(.system(size: amountSize, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
        }
    }
}

struct CalendarMonthSummary: View {
    @ScaledMetric(relativeTo: .subheadline) private var labelSize = 13.0
    @ScaledMetric(relativeTo: .headline) private var amountSize = 17.0
    let aggregation: RecurringSpendAggregationResult?
    let hasEvents: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Итого за месяц"))
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(SoftClubColor.textSecondary)
                Spacer(minLength: 12)
                if let total = aggregation?.total {
                    Text(AmountLabel(total.amount, currency: total.currencyCode).formattedAmount)
                        .font(.system(size: amountSize, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(SoftClubColor.textPrimary)
                } else {
                    Text("—").foregroundStyle(SoftClubColor.textSecondary)
                }
            }
            if let aggregation { explanation(aggregation) }
            if !hasEvents {
                Text(String(localized: "calendar.emptyMonth"))
                    .font(.system(size: labelSize, weight: .regular))
                    .foregroundStyle(SoftClubColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func explanation(_ aggregation: RecurringSpendAggregationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            switch aggregation {
            case let .complete(_, metadata):
                staleRate(metadata)
            case let .partial(_, missingCodes, metadata):
                Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                staleRate(metadata)
            case let .unavailable(_, missingCodes, _, metadata):
                Text(String(localized: "Курсы валют недоступны"))
                if !missingCodes.isEmpty {
                    Text(String(localized: "Нет курсов для \(missingCodes.joined(separator: ", "))"))
                }
                staleRate(metadata)
            }
        }
        .font(.system(size: labelSize, weight: .regular))
        .foregroundStyle(SoftClubColor.textSecondary)
    }

    @ViewBuilder private func staleRate(_ metadata: SpendAggregationRateMetadata?) -> some View {
        if let metadata, case .stale = metadata.freshness {
            Text(String(localized: "По сохранённому курсу"))
        }
    }
}
