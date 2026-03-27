import SwiftUI

// MARK: - Empty State

/// Shown when a list or screen has no content.
///
/// Usage:
/// ```swift
/// EmptyStateView(
///     icon: "tray",
///     title: "No subscriptions yet",
///     subtitle: "Add your first recurring payment to get started.",
///     actionTitle: "Add Item"
/// ) { /* action */ }
/// ```
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(subtitle)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorTokens.accent, in: Capsule())
                }
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading State

/// Centered loading indicator with optional message.
struct LoadingStateView: View {
    let message: String

    init(_ message: String = "Загрузка...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ProgressView()
                .controlSize(.large)

            Text(message)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State

/// Shown when an operation fails.
struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Что-то пошло не так",
        message: String,
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(ColorTokens.error)

            VStack(spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(message)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction {
                Button(action: retryAction) {
                    Text("Повторить")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xl)
                        .padding(.vertical, Spacing.sm)
                        .background(ColorTokens.accent, in: Capsule())
                }
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Empty State") {
    EmptyStateView(
        icon: "tray",
        title: "No subscriptions yet",
        subtitle: "Add your first recurring payment to get started.",
        actionTitle: "Add Item"
    ) {}
    .background(ColorTokens.background)
}

#Preview("Loading State") {
    LoadingStateView("Loading subscriptions...")
        .background(ColorTokens.background)
}

#Preview("Error State") {
    ErrorStateView(
        message: "Could not load your data. Please try again."
    ) {}
    .background(ColorTokens.background)
}
