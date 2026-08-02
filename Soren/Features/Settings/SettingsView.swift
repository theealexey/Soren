import SwiftUI

// MARK: - Settings View

/// App settings: default currency and appearance.
/// Presented as a sheet from the gear icon on Home and Alerts screens.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppContainer.self) private var container
    @State private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

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

            notificationPermissionSection

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
        .task {
            await viewModel.loadNotificationAuthorizationStatus()
        }
        .task(id: container.notificationObservation.revision) {
            guard container.notificationObservation.revision > 0 else { return }
            viewModel.applyForegroundAuthorizationStatus(container.notificationObservation.authorizationStatus)
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

    private var notificationPermissionSection: some View {
        Section(String(localized: "Разрешение на уведомления")) {
            Text(String(localized: "Soren использует системное разрешение iOS для напоминаний о списаниях и пробных периодах."))
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)

            HStack {
                Text(String(localized: "Статус"))
                Spacer()
                if viewModel.isNotificationStatusLoading {
                    ProgressView()
                } else {
                    Text(viewModel.notificationStatusText)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            if viewModel.isNotificationActionInFlight {
                HStack(spacing: Spacing.sm) {
                    ProgressView()
                    Text(String(localized: "Обновляем настройки уведомлений"))
                }
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Обновляем настройки уведомлений"))
            } else if let actionTitle = viewModel.notificationPrimaryActionTitle {
                Button(actionTitle) {
                    Task { await viewModel.performNotificationPrimaryAction() }
                }
                .accessibilityLabel(actionTitle)
            }

            if let errorText = viewModel.notificationErrorText {
                Text(errorText)
                    .font(Typography.caption)
                    .foregroundStyle(.red)
            }

            if let warningText = viewModel.notificationWarningText {
                Text(warningText)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
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
            if let provider = container.notificationDiagnosticsProvider {
                NavigationLink(String(localized: "Диагностика уведомлений")) {
                    NotificationDiagnosticsView(provider: provider)
                }
            }

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
