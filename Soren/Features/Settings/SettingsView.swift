import SwiftUI

// MARK: - Settings View

/// App settings: default currency, appearance, notification preferences.
/// Presented as a sheet from gear icon on Home and Alerts screens.
struct SettingsView: View {
    @Bindable var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            generalSection

            notificationsSection

            aboutSection
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Готово") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .preferredColorScheme(viewModel.preferredColorScheme)
    }

    // MARK: - General

    private var generalSection: some View {
        Section("Основное") {
            Picker("Валюта по умолчанию", selection: $viewModel.defaultCurrencyCode) {
                ForEach(SettingsViewModel.supportedCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Picker("Внешний вид", selection: $viewModel.appearanceMode) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Уведомления") {
            Stepper(
                "До списания: \(viewModel.chargeAlertDays) дн.",
                value: $viewModel.chargeAlertDays,
                in: 1...14
            )

            Stepper(
                "До конца триала: \(viewModel.trialAlertDays) дн.",
                value: $viewModel.trialAlertDays,
                in: 1...14
            )
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("О приложении") {
            HStack {
                Text("Версия")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            HStack {
                Text("Сборка")
                Spacer()
                Text(viewModel.buildNumber)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
