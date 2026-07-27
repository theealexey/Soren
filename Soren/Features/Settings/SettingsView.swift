import SwiftUI

// MARK: - Settings View

/// App settings: default currency and appearance.
/// Presented as a sheet from the gear icon on Home and Alerts screens.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    #if DEBUG
    @Environment(AppContainer.self) private var container
    #endif

    var body: some View {
        @Bindable var vm = viewModel
        @Bindable var appState = appState
        Form {
            generalSection(
                currency:       $vm.defaultCurrencyCode,
                pricingMarket:  $vm.pricingMarket,
                appearance:     $appState.appearanceMode,
                chargeReminder: $vm.defaultChargeReminder
            )

            aboutSection

            #if DEBUG
            developerSection
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
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
        .onChange(of: appState.appearanceMode) {
            dismiss()
        }
    }

    // MARK: - General

    @ViewBuilder
    private func generalSection(
        currency:       Binding<String>,
        pricingMarket:  Binding<PricingMarket>,
        appearance:     Binding<AppearanceMode>,
        chargeReminder: Binding<ChargeReminderOption>
    ) -> some View {
        Section("Основное") {
            Picker("Валюта по умолчанию", selection: currency) {
                ForEach(SettingsViewModel.supportedCurrencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }

            Picker("Рынок цен", selection: pricingMarket) {
                ForEach(SettingsViewModel.supportedPricingMarkets, id: \.self) { market in
                    Text(pricingMarketName(market)).tag(market)
                }
            }

            Text("Выберите рынок для цен из каталога. Это не влияет на валюту отчётов.")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            Picker("Внешний вид", selection: appearance) {
                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }

        Section("Уведомления") {
            Picker("Напоминание по умолчанию", selection: chargeReminder) {
                ForEach(ChargeReminderOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }

    private func pricingMarketName(_ market: PricingMarket) -> LocalizedStringKey {
        switch market.countryCode {
        case "RU": "Россия"
        default: "США"
        }
    }

    // MARK: - Developer (DEBUG only)

    #if DEBUG
    /// Seed / clear controls for App Store screenshot sessions.
    /// Compiled out entirely in Release builds.
    private var developerSection: some View {
        let seeder = DemoDataSeeder(
            repositories: container.repositories,
            preferences: container.preferences
        )
        return Section("Разработка") {
            Button("Загрузить демо-данные") {
                try? seeder.seed()
                container.itemsVersion += 1
            }
            .disabled(seeder.isDemoDataPresent)

            Button("Очистить демо-данные", role: .destructive) {
                try? seeder.clear()
                container.itemsVersion += 1
            }
            .disabled(!seeder.isDemoDataPresent)
        }
    }
    #endif

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
            .environment(
                AppContainer(modelContext: try! SorenModelContainer.inMemory().mainContext)
            )
    }
}
