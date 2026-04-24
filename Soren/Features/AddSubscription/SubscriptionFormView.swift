import SwiftUI

// MARK: - Subscription Form View

/// Step 2 of Add Subscription: fill in details and save.
/// Fields are pre-filled when a provider was selected in the picker.
struct SubscriptionFormView: View {
    @Bindable var viewModel: AddSubscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveError = false

    var body: some View {
        Form {
            providerHeader

            tierSection

            RecurringItemFormFields(
                title: $viewModel.title,
                amountText: $viewModel.amountText,
                currencyCode: currencyBinding,
                billingCycle: $viewModel.billingCycle,
                category: $viewModel.category,
                itemType: $viewModel.itemType,
                startDate: $viewModel.startDate,
                nextChargeDate: nextChargeDateBinding,
                autoRenew: $viewModel.autoRenew,
                endDate: endDateBinding,
                note: $viewModel.note,
                usageStatus: $viewModel.usageStatus,
                chargeReminder: $viewModel.chargeReminder,
                trialReminder: $viewModel.trialReminder,
                showsTrialReminder: false
            )
        }
        .scrollContentBackground(.hidden)
        .background(ColorTokens.background)
        .navigationTitle(viewModel.selectedProvider != nil
            ? String(localized: "Новая подписка")
            : String(localized: "Добавить вручную"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Сохранить")) {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.canSave)
            }
        }
        .alert(String(localized: "Не удалось сохранить"), isPresented: $showSaveError) {
            Button(String(localized: "ОК"), role: .cancel) {}
        } message: {
            Text(viewModel.saveError?.localizedDescription ?? "")
        }
    }

    // MARK: - Next Charge Date Binding

    /// Routes the next-charge-date setter through setNextChargeDateManually so the ViewModel
    /// records a manual override and stops auto-suggesting on subsequent startDate / billingCycle changes.
    private var nextChargeDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.nextChargeDate },
            set: { viewModel.setNextChargeDateManually($0) }
        )
    }

    // MARK: - End Date Binding

    /// Routes the end-date setter through setEndDateManually so the ViewModel records
    /// that the user has explicitly chosen a date and stops auto-filling on cycle changes.
    private var endDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.endDate },
            set: { viewModel.setEndDateManually($0) }
        )
    }

    // MARK: - Currency Binding

    /// Triggers amount conversion only when the user explicitly changes the currency Picker.
    /// Avoids the `onChange` race where a programmatic `currencyCode` write during provider
    /// selection fires conversion before the tier amount is written to `amountText`.
    private var currencyBinding: Binding<String> {
        Binding(
            get: { viewModel.currencyCode },
            set: { newCode in
                let old = viewModel.currencyCode
                viewModel.currencyCode = newCode
                if old != newCode {
                    Task { await viewModel.convertAmount(from: old, to: newCode) }
                }
            }
        )
    }

    // MARK: - Provider Header

    @ViewBuilder
    private var providerHeader: some View {
        if let provider = viewModel.selectedProvider {
            Section {
                HStack(spacing: Spacing.sm) {
                    ProviderIcon(provider: provider, size: .large)

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

    // MARK: - Plan Tier Selection

    @ViewBuilder
    private var tierSection: some View {
        if !viewModel.availableTiers.isEmpty {
            Section("Тариф") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.sm) {
                        ForEach(viewModel.availableTiers) { tier in
                            TierChipView(
                                tier: tier,
                                currencyCode: viewModel.currencyCode,
                                isSelected: viewModel.selectedTier?.id == tier.id
                            )
                            .onTapGesture {
                                if viewModel.selectedTier?.id == tier.id {
                                    viewModel.clearTier()
                                } else {
                                    viewModel.selectTier(tier)
                                }
                                HapticEngine.selection()
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.xxs)
                }
                .listRowInsets(EdgeInsets(
                    top: Spacing.xs,
                    leading: Spacing.xxs,
                    bottom: Spacing.xs,
                    trailing: Spacing.xxs
                ))
            }
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
            showSaveError = true
        }
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
