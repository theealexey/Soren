import SwiftUI

// MARK: - Item Edit Form View

/// Modal form for editing an existing recurring item.
/// Binds to edit fields in ItemDetailsViewModel.
struct ItemEditFormView: View {
    @Bindable var viewModel: ItemDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            RecurringItemFormFields(
                title: $viewModel.editTitle,
                amountText: $viewModel.editAmountText,
                currencyCode: $viewModel.editCurrencyCode,
                billingCycle: $viewModel.editBillingCycle,
                category: $viewModel.editCategory,
                itemType: $viewModel.editItemType,
                startDate: $viewModel.editStartDate,
                nextChargeDate: editNextChargeDateBinding,
                autoRenew: $viewModel.editAutoRenew,
                endDate: editEndDateBinding,
                note: $viewModel.editNote,
                usageStatus: $viewModel.editUsageStatus,
                chargeReminder: $viewModel.editChargeReminder,
                trialReminder: $viewModel.editTrialReminder,
                showsTrialReminder: viewModel.item.trialEndDate != nil
            )
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
        .navigationTitle(String(localized: "Редактирование"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Отмена")) {
                    viewModel.cancelEditing()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Сохранить")) {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave)
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: viewModel.editCurrencyCode) { old, new in
            Task { await viewModel.convertAmount(from: old, to: new) }
        }
    }

    // MARK: - Next Charge Date Binding

    /// Routes the next-charge-date setter through setEditNextChargeDateManually so
    /// subsequent startDate / billingCycle changes will not overwrite the user's pick.
    private var editNextChargeDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.editNextChargeDate },
            set: { viewModel.setEditNextChargeDateManually($0) }
        )
    }

    // MARK: - End Date Binding

    private var editEndDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.editEndDate },
            set: { viewModel.setEditEndDateManually($0) }
        )
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
                    ),
                    exchangeRateProvider: StaticExchangeRateProvider()
                )
                vm.startEditing()
                return vm
            }()
        )
    }
}
