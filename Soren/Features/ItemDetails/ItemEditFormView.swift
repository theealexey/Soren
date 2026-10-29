import SwiftUI

// MARK: - Item Edit Form View

/// Modal form for editing an existing recurring item.
/// Binds to edit fields in ItemDetailsViewModel.
struct ItemEditFormView: View {
    @Bindable var viewModel: ItemDetailsViewModel

    var body: some View {
        Form {
            RecurringItemFormFields(
                title: $viewModel.editTitle,
                amountText: $viewModel.editAmountText,
                currencyCode: $viewModel.editCurrencyCode,
                currencyEstimateState: viewModel.currencyEstimateState,
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
            .disabled(viewModel.isPerformingAction)
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
                .disabled(viewModel.isPerformingAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Сохранить")) {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave || viewModel.isPerformingAction)
            }
        }
        .interactiveDismissDisabled()
        .alert(
            viewModel.actionFailure?.intent.failureTitle ?? String(localized: "itemDetails.action.saveFailed"),
            isPresented: Binding(
                get: { viewModel.actionFailure != nil },
                set: { if !$0 { viewModel.dismissActionFailure() } }
            ),
            presenting: viewModel.actionFailure
        ) { failure in
            if failure.canRetry {
                Button(String(localized: "Повторить")) { saveAndDismiss() }
            }
            Button(failure.kind == .invalidInput
                ? String(localized: "itemDetails.action.correct") : String(localized: "ОК"), role: .cancel) {
                viewModel.dismissActionFailure()
            }
        } message: { failure in
            Text(failure.message)
        }
        .onAppear {
            viewModel.refreshReportingCurrency()
        }
        .onDisappear {
            viewModel.cancelCurrencyEstimate()
        }
    }

    // MARK: - Next Charge Date Binding

    /// Routes the next-charge-date setter through setEditNextChargeDateManually so
    /// subsequent startDate / billingCycle changes will not overwrite the user's pick.
    private var editNextChargeDateBinding: Binding<CivilDate?> {
        Binding(
            get: { viewModel.editNextChargeDate },
            set: { viewModel.setEditNextChargeDateManually($0) }
        )
    }

    // MARK: - End Date Binding

    private var editEndDateBinding: Binding<CivilDate?> {
        Binding(
            get: { viewModel.editEndDate },
            set: { viewModel.setEditEndDateManually($0) }
        )
    }

    // MARK: - Save

    private func saveAndDismiss() {
        Task {
            do {
                if try await viewModel.saveChanges() { HapticEngine.success() }
            } catch {
                HapticEngine.error()
            }
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
