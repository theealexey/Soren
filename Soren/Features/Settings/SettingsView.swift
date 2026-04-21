import SwiftUI

// MARK: - Settings View

/// App settings: default currency and appearance.
/// Presented as a sheet from the gear icon on Home and Alerts screens.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var vm = viewModel
        @Bindable var appState = appState
        Form {
            generalSection(
                currency: $vm.defaultCurrencyCode,
                appearance: $appState.appearanceMode
            )

            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
        .preferredColorScheme(appState.appearanceMode.colorScheme)
        .navigationTitle(String(localized: "Настройки"))
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
            .environment(AppState())
    }
}
