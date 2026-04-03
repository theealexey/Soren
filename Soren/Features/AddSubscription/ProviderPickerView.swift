import SwiftUI

// MARK: - Provider Picker View

/// Step 1 of Add Subscription: pick a provider from catalog or start manual entry.
/// Shows popular services grid, searchable full catalog grouped by category.
struct ProviderPickerView: View {
    @Bindable var viewModel: AddSubscriptionViewModel

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.sm),
        GridItem(.flexible(), spacing: Spacing.sm),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                manualEntryButton

                if viewModel.searchText.isEmpty {
                    popularSection
                }

                catalogSections
            }
            .padding(.vertical, Spacing.md)
        }
        .navigationTitle("Добавить")
        .searchable(
            text: $viewModel.searchText,
            prompt: "Поиск сервисов"
        )
        .task {
            await viewModel.loadProviders()
        }
    }

    // MARK: - Manual Entry

    private var manualEntryButton: some View {
        NavigationLink {
            SubscriptionFormView(viewModel: viewModel)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(Typography.bodyMedium)
                    .foregroundStyle(ColorTokens.accent)
                    .frame(width: 40, height: 40)
                    .background(ColorTokens.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium))

                Text("Добавить вручную")
                    .font(Typography.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Typography.caption)
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.lg)
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.startManualEntry()
        })
    }

    // MARK: - Popular Services

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Популярные"))
                .padding(.horizontal, Spacing.lg)

            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(viewModel.popularProviders, id: \.id) { provider in
                    popularProviderCard(provider)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func popularProviderCard(_ provider: ProviderTemplate) -> some View {
        NavigationLink {
            SubscriptionFormView(viewModel: viewModel)
        } label: {
            VStack(spacing: Spacing.xs) {
                ProviderIcon(provider: provider, size: .large)

                Text(provider.displayName)
                    .font(Typography.captionMedium)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(ColorTokens.surfaceElevated, in: RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            viewModel.selectProvider(provider)
        })
    }

    // MARK: - Catalog by Category

    private var catalogSections: some View {
        ForEach(viewModel.providersByCategory, id: \.category) { group in
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SectionHeader(group.category.displayName)
                    .padding(.horizontal, Spacing.lg)

                PremiumCard {
                    VStack(spacing: 0) {
                        ForEach(Array(group.providers.enumerated()), id: \.element.id) { index, provider in
                            NavigationLink {
                                SubscriptionFormView(viewModel: viewModel)
                            } label: {
                                catalogRow(provider)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                viewModel.selectProvider(provider)
                            })

                            if index < group.providers.count - 1 {
                                Divider()
                                    .padding(.leading, SorenListRow.dividerInset)
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private func catalogRow(_ provider: ProviderTemplate) -> some View {
        HStack(spacing: Spacing.sm) {
            ProviderIcon(provider: provider, size: .medium)

            Text(provider.displayName)
                .font(Typography.headline)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProviderPickerView(
            viewModel: AddSubscriptionViewModel(
                catalog: InMemoryProviderCatalogRepository(),
                saveRecurringItem: SaveRecurringItem(
                    repository: try! RepositoryContainer(
                        context: SorenModelContainer.inMemory().mainContext
                    ).recurringItems
                )
            )
        )
    }
}
