import SwiftUI

// MARK: - Filter Chip

/// Selectable pill for filtering lists.
/// Used in Library, Analytics, Calendar screens.
///
/// Usage:
/// ```swift
/// FilterChip("Active", isSelected: $filter.active)
/// FilterChip("Trial", icon: "clock", tint: .purple, isSelected: $filter.trial)
/// ```
struct FilterChip: View {
    let title: String
    let icon: String?
    let tint: Color
    @Binding var isSelected: Bool

    init(
        _ title: String,
        icon: String? = nil,
        tint: Color = ColorTokens.accent,
        isSelected: Binding<Bool>
    ) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self._isSelected = isSelected
    }

    var body: some View {
        Button {
            isSelected.toggle()
            HapticEngine.selection()
        } label: {
            HStack(spacing: Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }

                Text(title)
                    .font(Typography.captionMedium)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(isSelected ? .white : ColorTokens.textSecondary)
            .background(
                isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(ColorTokens.surfaceElevated),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? .clear : ColorTokens.separator.opacity(0.5),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(MotionTokens.snappy, value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    struct ChipDemo: View {
        @State private var filters = [true, false, false, true, false]

        var body: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    FilterChip("All", isSelected: $filters[0])
                    FilterChip("Active", icon: "checkmark.circle", tint: ColorTokens.success, isSelected: $filters[1])
                    FilterChip("Trial", icon: "clock", tint: ColorTokens.warning, isSelected: $filters[2])
                    FilterChip("Annual", icon: "calendar", isSelected: $filters[3])
                    FilterChip("Archived", icon: "archivebox", tint: ColorTokens.textTertiary, isSelected: $filters[4])
                }
                .padding(.horizontal, Spacing.lg)
            }
            .padding(.vertical, Spacing.lg)
            .background(ColorTokens.background)
        }
    }

    return ChipDemo()
}
