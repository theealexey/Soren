import SwiftUI

// MARK: - Store Recovery View

/// Shown when the SwiftData production store cannot be opened.
/// Forces explicit user consent before any data is deleted.
struct StoreRecoveryView: View {
    let onReset: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(ColorTokens.warning)

            VStack(spacing: Spacing.sm) {
                Text("Хранилище недоступно")
                    .font(Typography.title)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text("Не удалось открыть базу данных. Возможно, файл был повреждён во время синхронизации iCloud.")
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Label(String(localized: "Сбросить данные"), systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.error)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.background)
        .alert(String(localized: "Сбросить все данные?"), isPresented: $showConfirmation) {
            Button(String(localized: "Сбросить"), role: .destructive) { onReset() }
            Button(String(localized: "Отмена"), role: .cancel) { }
        } message: {
            Text("Все подписки и настройки будут удалены без возможности восстановления.")
        }
    }
}
