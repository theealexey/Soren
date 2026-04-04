import SwiftUI

// MARK: - Item Details View

/// Full details screen for a recurring item.
/// Shows financial info, dates, classification, notes, and quick actions.
struct ItemDetailsView: View {
    @Bindable var viewModel: ItemDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                heroSection

                if viewModel.item.status != .active {
                    statusBadge
                }

                infoCard

                costCard

                if !viewModel.item.note.isEmpty {
                    noteCard
                }

                if viewModel.item.isActiveTrial {
                    trialWarning
                }

                actionsSection
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
        .background(ColorTokens.background)
        .navigationTitle(viewModel.item.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.startEditing()
                } label: {
                    Image(systemName: "pencil")
                        .font(Typography.bodyMedium)
                        .foregroundStyle(ColorTokens.accent)
                }
            }
        }
        .sheet(isPresented: $viewModel.isEditing) {
            NavigationStack {
                ItemEditFormView(viewModel: viewModel)
            }
        }
        .confirmationDialog(
            "Удалить подписку?",
            isPresented: $viewModel.showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                deleteAndDismiss()
            }
            Button("Отменить", role: .cancel) { }
        } message: {
            Text("«\(viewModel.item.title)» будет удалена без возможности восстановления.")
        }
        .onChange(of: viewModel.isDeleted) { _, deleted in
            if deleted { dismiss() }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.sm) {
            Group {
                if let provider = ProviderCatalog.template(forProviderID: viewModel.item.providerID) {
                    ProviderIcon(provider: provider, size: .large)
                } else {
                    ProviderIcon(category: viewModel.item.category, size: .large)
                }
            }

            Text(viewModel.item.title)
                .font(Typography.title)
                .foregroundStyle(ColorTokens.textPrimary)

            AmountLabel(
                viewModel.item.amount,
                currency: viewModel.item.currencyCode,
                size: .hero,
                cycle: viewModel.cycleLabel
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: viewModel.statusIcon)
                .font(Typography.captionMedium)

            Text(viewModel.item.status.displayName)
                .font(Typography.captionMedium)
        }
        .foregroundStyle(viewModel.statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(viewModel.statusColor.opacity(0.12), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Информация"))

            PremiumCard {
                VStack(spacing: 0) {
                    infoRow(
                        icon: "repeat",
                        label: "Цикл",
                        value: viewModel.item.billingCycle.displayName
                    )

                    Divider().padding(.leading, infoRowInset)

                    infoRow(
                        icon: "calendar",
                        label: "Следующее списание",
                        value: viewModel.formattedNextCharge
                    )

                    Divider().padding(.leading, infoRowInset)

                    infoRow(
                        icon: "calendar.badge.clock",
                        label: "Дата начала",
                        value: viewModel.formattedStartDate
                    )

                    Divider().padding(.leading, infoRowInset)

                    infoRow(
                        icon: viewModel.item.category.systemIconName,
                        label: "Категория",
                        value: viewModel.item.category.displayName
                    )

                    Divider().padding(.leading, infoRowInset)

                    infoRow(
                        icon: viewModel.item.itemType.systemIconName,
                        label: "Тип",
                        value: viewModel.item.itemType.displayName
                    )

                    Divider().padding(.leading, infoRowInset)

                    infoRow(
                        icon: "banknote",
                        label: "Валюта",
                        value: viewModel.item.currencyCode
                    )
                }
            }
        }
    }

    // MARK: - Cost Card

    private var costCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Стоимость"))

            HStack(spacing: Spacing.sm) {
                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В месяц",
                        amount: viewModel.item.monthlyEquivalent,
                        currency: viewModel.item.currencyCode,
                        amountSize: .large
                    )
                }

                PremiumCard(.elevated) {
                    StatBlock(
                        title: "В год",
                        amount: viewModel.item.annualEquivalent,
                        currency: viewModel.item.currencyCode,
                        amountSize: .large
                    )
                }
            }
        }
    }

    // MARK: - Note Card

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Заметка"))

            PremiumCard {
                Text(viewModel.item.note)
                    .font(Typography.body)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    // MARK: - Trial Warning

    private var trialWarning: some View {
        InsightCard(
            icon: "clock.badge.exclamationmark",
            title: String(localized: "Пробный период"),
            subtitle: RecurringItemFormatter.trialSubtitle(for: viewModel.item),
            severity: trialSeverity
        )
    }

    private var trialSeverity: InsightCard.Severity {
        guard let days = viewModel.item.daysUntilTrialEnd else { return .info }
        if days <= 1 { return .critical }
        if days <= 3 { return .warning }
        return .info
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: Spacing.xs) {
            actionButton(
                title: String(localized: "Редактировать"),
                icon: "pencil",
                color: ColorTokens.accent
            ) {
                viewModel.startEditing()
            }

            actionButton(
                title: viewModel.item.status == .paused
                    ? String(localized: "Возобновить")
                    : String(localized: "Приостановить"),
                icon: viewModel.item.status == .paused ? "play.fill" : "pause.fill",
                color: ColorTokens.warning
            ) {
                do {
                    try viewModel.togglePause()
                    HapticEngine.selection()
                } catch { HapticEngine.error() }
            }

            if viewModel.item.status != .archived {
                actionButton(
                    title: String(localized: "Архивировать"),
                    icon: "archivebox",
                    color: ColorTokens.textSecondary
                ) {
                    do {
                        try viewModel.archive()
                        HapticEngine.selection()
                    } catch { HapticEngine.error() }
                }
            }

            actionButton(
                title: String(localized: "Удалить"),
                icon: "trash",
                color: ColorTokens.error
            ) {
                viewModel.showDeleteConfirmation = true
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private func infoRow(icon: String, label: LocalizedStringKey, value: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.accent)
                .frame(width: 24, alignment: .center)

            Text(label)
                .font(Typography.body)
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()

            Text(value)
                .font(Typography.bodyMedium)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .padding(.vertical, Spacing.xs)
    }

    private let infoRowInset: CGFloat = 24 + Spacing.sm

    private func actionButton(
        title: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(ColorTokens.surface, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }

    private func deleteAndDismiss() {
        do {
            try viewModel.delete()
            HapticEngine.success()
        } catch {
            HapticEngine.error()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ItemDetailsView(
            viewModel: ItemDetailsViewModel(
                item: RecurringItem(
                    title: "YouTube Premium",
                    providerID: "youtube_premium",
                    providerName: "YouTube Premium",
                    category: .video,
                    amount: 299,
                    currencyCode: "RUB",
                    billingCycle: .monthly,
                    nextChargeDate: Calendar.current.date(byAdding: .day, value: 5, to: .now)!,
                    note: "Семейная подписка, 6 аккаунтов"
                ),
                repositories: RepositoryContainer(
                    context: try! SorenModelContainer.inMemory().mainContext
                )
            )
        )
    }
}
