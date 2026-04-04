import SwiftUI

// MARK: - Settings View

/// App settings: default currency, appearance, notification preferences.
/// Presented as a sheet from gear icon on Home and Alerts screens.
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        Form {
            generalSection(
                currency: $vm.defaultCurrencyCode,
                appearance: $vm.appearanceMode
            )

            notificationsSection(
                chargeAlertDays: $vm.chargeAlertDays,
                trialAlertDays: $vm.trialAlertDays
            )

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
    }

    // MARK: - General

    private func generalSection(
        currency: Binding<String>,
        appearance: Binding<AppearanceMode>
    ) -> some View {
        Section("Основное") {
            Picker("Валюта по умолчанию", selection: currency) {
                ForEach(SettingsViewModel.supportedCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Picker("Внешний вид", selection: appearance) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
    }

    // MARK: - Notifications

    private func notificationsSection(
        chargeAlertDays: Binding<Int>,
        trialAlertDays: Binding<Int>
    ) -> some View {
        Section("Уведомления") {
            Stepper(
                "До списания: \(viewModel.chargeAlertDays) дн.",
                value: chargeAlertDays,
                in: 1...14
            )

            Stepper(
                "До конца триала: \(viewModel.trialAlertDays) дн.",
                value: trialAlertDays,
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
