import SwiftUI

// MARK: - Item Edit Form View

/// Modal form for editing an existing recurring item.
/// Binds to edit fields in ItemDetailsViewModel.
struct ItemEditFormView: View {
    @Bindable var viewModel: ItemDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            essentialsSection

            classificationSection

            datesSection

            noteSection
        }
        .navigationTitle("Редактирование")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Отмена") {
                    viewModel.cancelEditing()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Сохранить") {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave)
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Essentials

    private var essentialsSection: some View {
        Section("Основное") {
            TextField("Название", text: $viewModel.editTitle)

            HStack {
                TextField("Сумма", text: $viewModel.editAmountText)
                    .keyboardType(.decimalPad)

                Picker("", selection: $viewModel.editCurrencyCode) {
                    ForEach(supportedCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Picker("Период оплаты", selection: $viewModel.editBillingCycle) {
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Text(cycle.displayName).tag(cycle)
                }
            }
        }
    }

    // MARK: - Classification

    private var classificationSection: some View {
        Section("Категория") {
            Picker("Категория", selection: $viewModel.editCategory) {
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }

            Picker("Тип", selection: $viewModel.editItemType) {
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
                selection: $viewModel.editStartDate,
                displayedComponents: .date
            )

            DatePicker(
                "Следующее списание",
                selection: $viewModel.editNextChargeDate,
                displayedComponents: .date
            )
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        Section("Заметка") {
            TextField("Тариф, аккаунт, детали...", text: $viewModel.editNote, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        do {
            try viewModel.saveChanges()
            HapticEngine.success()
            dismiss()
        } catch {
            HapticEngine.error()
        }
    }

    // MARK: - Supported Currencies

    private var supportedCurrencies: [String] {
        SupportedCurrency.codes
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ItemEditFormView(
            viewModel: {
                let vm = ItemDetailsViewModel(
                    item: RecurringItem(
                        title: "Spotify",
                        category: .music,
                        amount: 299,
                        nextChargeDate: .now
                    ),
                    repositories: RepositoryContainer(
                        context: try! SorenModelContainer.inMemory().mainContext
                    )
                )
                vm.startEditing()
                return vm
            }()
        )
    }
}
