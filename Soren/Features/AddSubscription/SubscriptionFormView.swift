import SwiftUI

// MARK: - Subscription Form View

/// Step 2 of Add Subscription: fill in details and save.
/// Fields are pre-filled when a provider was selected in the picker.
struct SubscriptionFormView: View {
    @Bindable var viewModel: AddSubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            providerHeader

            essentialsSection

            classificationSection

            datesSection

            noteSection
        }
        .navigationTitle(viewModel.selectedProvider != nil
            ? String(localized: "Новая подписка")
            : String(localized: "Добавить вручную"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave)
            }
        }
    }

    // MARK: - Provider Header

    @ViewBuilder
    private var providerHeader: some View {
        if let provider = viewModel.selectedProvider {
            Section {
                HStack(spacing: Spacing.sm) {
                    ProviderIcon(
                        systemName: provider.category.systemIconName,
                        color: provider.category.color,
                        size: .large
                    )

                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(provider.displayName)
                            .font(Typography.headline)
                            .foregroundStyle(ColorTokens.textPrimary)

                        Text(provider.category.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Essentials

    private var essentialsSection: some View {
        Section("Основное") {
            TextField("Название", text: $viewModel.title)

            HStack {
                TextField("Сумма", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)

                Picker("", selection: $viewModel.currencyCode) {
                    ForEach(supportedCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Picker("Период оплаты", selection: $viewModel.billingCycle) {
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Text(cycle.displayName).tag(cycle)
                }
            }
        }
    }

    // MARK: - Classification

    private var classificationSection: some View {
        Section("Категория") {
            Picker("Категория", selection: $viewModel.category) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }

            Picker("Тип", selection: $viewModel.itemType) {
                ForEach(ItemType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        }
    }

    // MARK: - Dates

    private var datesSection: some View {
        Section("Даты") {
            DatePicker(
                "Дата начала",
                selection: $viewModel.startDate,
                displayedComponents: .date
            )

            DatePicker(
                "Следующее списание",
                selection: $viewModel.nextChargeDate,
                displayedComponents: .date
            )
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        Section("Заметка") {
            TextField("Тариф, аккаунт, детали...", text: $viewModel.note, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        do {
            try viewModel.save()
            HapticEngine.success()
            dismiss()
        } catch {
            HapticEngine.error()
        }
    }

    // MARK: - Supported Currencies

    private var supportedCurrencies: [String] {
        ["RUB", "USD", "EUR", "GBP", "TRY", "KZT", "BYN", "GEL", "AMD", "AED", "JPY", "CNY"]
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionFormView(
            viewModel: {
                let vm = AddSubscriptionViewModel(
                    catalog: InMemoryProviderCatalogRepository(),
                    saveRecurringItem: SaveRecurringItem(
                        repository: try! RepositoryContainer(
                            context: SorenModelContainer.inMemory().mainContext
                        ).recurringItems
                    )
                )
                vm.selectProvider(ProviderCatalog.all.first!)
                return vm
            }()
        )
    }
}
