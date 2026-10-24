import SwiftUI

// MARK: - Subscription Form View

/// Step 2 of Add Subscription: fill in details and save.
/// Fields are pre-filled when a provider was selected in the picker.
struct SubscriptionFormView: View {
    @Bindable var viewModel: AddSubscriptionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSaveError = false
    @State private var isSubmitting = false

    var body: some View {
        Form {
            providerHeader

            tierSection

            regionalPricingSection

            RecurringItemFormFields(
                title: $viewModel.title,
                amountText: $viewModel.amountText,
                currencyCode: $viewModel.currencyCode,
                currencyEstimateState: viewModel.currencyEstimateState,
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
                .disabled(isSubmitting || !viewModel.canSave)
            }
        }
        .alert(String(localized: "Не удалось сохранить"), isPresented: $showSaveError) {
            Button(String(localized: "ОК"), role: .cancel) {}
        } message: {
            Text(viewModel.saveErrorMessage ?? "")
        }
        .onAppear {
            viewModel.refreshPreferences()
        }
        .onDisappear {
            viewModel.cancelCurrencyEstimate()
        }
    }

    // MARK: - Next Charge Date Binding

    /// Routes the next-charge-date setter through setNextChargeDateManually so the ViewModel
    /// records a manual override and stops auto-suggesting on subsequent startDate / billingCycle changes.
    private var nextChargeDateBinding: Binding<CivilDate?> {
        Binding(
            get: { viewModel.nextChargeDate },
            set: { viewModel.setNextChargeDateManually($0) }
        )
    }

    // MARK: - End Date Binding

    /// Routes the end-date setter through setEndDateManually so the ViewModel records
    /// that the user has explicitly chosen a date and stops auto-filling on cycle changes.
    private var endDateBinding: Binding<CivilDate?> {
        Binding(
            get: { viewModel.endDate },
            set: { viewModel.setEndDateManually($0) }
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
                            Button {
                                if viewModel.selectedTier?.id == tier.id {
                                    viewModel.clearTier()
                                } else {
                                    viewModel.selectTier(tier)
                                }
                                HapticEngine.selection()
                            } label: {
                                TierChipView(
                                    tier: tier,
                                    pricingPresentation: viewModel.tierPricingPresentation(for: tier),
                                    isSelected: viewModel.selectedTier?.id == tier.id
                                )
                            }
                            .buttonStyle(.plain)
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

    // MARK: - Regional Pricing

    @ViewBuilder
    private var regionalPricingSection: some View {
        if viewModel.selectedProvider != nil {
            Section("Цена по рынку") {
                LabeledContent("Рынок цен") {
                    Text(viewModel.pricingMarketPresentation.displayName)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .accessibilityElement(children: .combine)

                RegionalPricingStatusView(
                    presentation: viewModel.pricingPresentation
                )
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        guard !isSubmitting, viewModel.canSave else { return }
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                if try await viewModel.save() {
                    HapticEngine.success()
                    dismiss()
                }
            } catch {
                HapticEngine.error()
                showSaveError = true
            }
        }
    }

}

// MARK: - Regional Pricing Status

private struct RegionalPricingStatusView: View {
    let presentation: AddSubscriptionPricingPresentation

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .noTierSelected:
            EmptyView()

        case .verified(let quote):
            RegionalQuoteDetailsView(
                quote: quote,
                statusTitle: "Подтверждённая цена",
                quoteTitle: "Цена для выбранного рынка",
                systemImage: "checkmark.seal.fill",
                tint: ColorTokens.success,
                guidance: nil
            )

        case .requiresReview(let quote):
            RegionalQuoteDetailsView(
                quote: quote,
                statusTitle: "Цена требует проверки",
                quoteTitle: "Последняя известная цена",
                systemImage: "exclamationmark.triangle.fill",
                tint: ColorTokens.warning,
                guidance: "Введите сумму вручную"
            )

        case .unavailable:
            RegionalManualPricingStatusView(
                title: "Нет подтверждённой цены",
                message: "Для выбранного рынка нет подтверждённой цены. Введите сумму вручную.",
                systemImage: "pencil.circle",
                tint: ColorTokens.info
            )

        case .loaderFailure:
            RegionalManualPricingStatusView(
                title: "Данные о ценах недоступны",
                message: "Введите сумму вручную. Сохранение подписки остаётся доступным.",
                systemImage: "exclamationmark.circle",
                tint: ColorTokens.info
            )

        case .userModified:
            RegionalManualPricingStatusView(
                title: "Цена изменена вручную",
                message: "Введённые вручную сумма, валюта и период будут сохранены.",
                systemImage: "pencil.circle.fill",
                tint: ColorTokens.info
            )
        }
    }
}

private struct RegionalQuoteDetailsView: View {
    let quote: AddSubscriptionRegionalQuotePresentation
    let statusTitle: LocalizedStringResource
    let quoteTitle: LocalizedStringResource
    let systemImage: String
    let tint: Color
    let guidance: LocalizedStringResource?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label {
                Text(statusTitle)
                    .font(Typography.captionMedium)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(quoteTitle)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)

                Text(
                    quote.money.amount,
                    format: .currency(code: quote.money.currencyCode)
                )
                .font(Typography.amountMedium)
                .foregroundStyle(ColorTokens.textPrimary)

                Text(quote.billingCycle.displayName)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .accessibilityElement(children: .combine)

            LabeledContent("Проверено") {
                Text(
                    quote.verifiedAt,
                    format: .dateTime.day().month(.wide).year()
                )
                .foregroundStyle(ColorTokens.textSecondary)
            }
            .font(Typography.caption)
            .accessibilityElement(children: .combine)

            if let guidance {
                Text(guidance)
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Link(destination: quote.sourceURL) {
                Label("Официальный источник цены", systemImage: "arrow.up.right.square")
                    .font(Typography.captionMedium)
            }
            .accessibilityLabel("Открыть официальный источник цены")
            .padding(.vertical, Spacing.xxxs)
        }
    }
}

private struct RegionalManualPricingStatusView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label {
                Text(title)
                    .font(Typography.captionMedium)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
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
