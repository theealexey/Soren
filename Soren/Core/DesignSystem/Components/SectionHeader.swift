import SwiftUI

// MARK: - Section Header

/// Consistent section header with optional trailing action.
///
/// Usage:
/// ```swift
/// SectionHeader("Upcoming charges")
/// SectionHeader("Active trials", action: "See all") { navigateToTrials() }
/// ```
struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(_ title: String, action actionTitle: String? = nil, perform action: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.sectionHeader)
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.captionMedium)
                        .foregroundStyle(ColorTokens.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.xl) {
        SectionHeader("Ближайшие списания")
        SectionHeader("Пробные периоды", action: "Все") {}
        SectionHeader("Этот месяц", action: "Подробнее") {}
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
