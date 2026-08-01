import Foundation

// MARK: - Subscription Form Factories

extension AppContainer {
    func makeAddSubscriptionViewModel() -> AddSubscriptionViewModel {
        AddSubscriptionViewModel(
            catalog: providerCatalog,
            saveRecurringItem: SaveRecurringItem(
                repository: repositories.recurringItems,
                notificationCoordinator: notificationRefreshCoordinator
            ),
            currencyEstimateService: makeCurrencyEstimateService(),
            preferences: preferences,
            regionalPricingSnapshotResult: regionalPricingSnapshotResult
        )
    }

    func makeItemDetailsViewModel(item: RecurringItem) -> ItemDetailsViewModel {
        ItemDetailsViewModel(
            item: item,
            updateRecurringItem: UpdateRecurringItem(
                repository: repositories.recurringItems,
                notificationCoordinator: notificationRefreshCoordinator
            ),
            deleteRecurringItem: DeleteRecurringItem(
                repository: repositories.recurringItems,
                notificationCoordinator: notificationRefreshCoordinator
            ),
            currencyEstimateService: makeCurrencyEstimateService(),
            preferences: preferences
        )
    }

    private func makeCurrencyEstimateService() -> CurrencyEstimateService {
        CurrencyEstimateService(
            exchangeRateProvider: exchangeRateProvider,
            convertMoney: ConvertMoneyUseCase()
        )
    }
}
