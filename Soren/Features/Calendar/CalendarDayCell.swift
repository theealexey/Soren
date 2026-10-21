import SwiftUI

struct CalendarDayCell: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var contrast
    @ScaledMetric(relativeTo: .caption) private var numberSize = 15.0
    @ScaledMetric(relativeTo: .caption) private var rowHeight = 52.0
    @ScaledMetric(relativeTo: .caption) private var plateHeight = 48.0

    let presentation: CalendarDayPresentation
    let calendar: Calendar
    let select: () -> Void

    var body: some View {
        Group {
            if presentation.isInteractive {
                Button(action: select) { content }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(presentation.accessibilityLabel(calendar: calendar))
                    .accessibilityAddTraits(presentation.isSelected ? .isSelected : [])
            } else {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(presentation.accessibilityLabel(calendar: calendar))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: rowHeight)
    }

    private var content: some View {
        VStack(spacing: 3) {
            Text(calendar.component(.day, from: presentation.day.date).formatted(.number.grouping(.never)))
                .font(.system(size: numberSize, weight: .regular))
                .foregroundStyle(presentation.day.isCurrentMonth ? SoftClubColor.textPrimary : SoftClubColor.textTertiary)
            Capsule()
                .fill(presentation.isToday ? SoftClubColor.signatureRed : Color.clear)
                .frame(width: 10, height: 2)
            if !dynamicTypeSize.isAccessibilitySize {
                marks
            }
        }
        .frame(width: 42, height: max(48, plateHeight))
        .background {
            if presentation.isSelected && presentation.isInteractive {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SoftClubColor.elevatedSurface)
                    .overlay {
                        if contrast == .increased {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(SoftClubColor.subtleBorder, lineWidth: 1)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, minHeight: max(44, rowHeight))
        .contentShape(Rectangle())
    }

    private var marks: some View {
        HStack(spacing: 3) {
            ForEach(Array(presentation.visibleMarks.enumerated()), id: \.offset) { _, occurrence in
                CalendarProviderMark(occurrence: occurrence)
            }
            if presentation.overflowCount > 0 {
                Text("+\(presentation.overflowCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize()
            }
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

private struct CalendarProviderMark: View {
    let occurrence: CalendarScheduleOccurrence

    var body: some View {
        Group {
            if let provider = occurrence.item.providerTemplate {
                ProviderIcon(provider: provider, size: .micro)
            } else {
                ProviderIcon(category: occurrence.item.category, size: .micro)
            }
        }
        .frame(width: 14, height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            if occurrence.money == nil {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(SoftClubColor.textSecondary, lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}
