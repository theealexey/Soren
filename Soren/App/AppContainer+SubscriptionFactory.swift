import Foundation

// MARK: - Subscription Form Factories

extension AppContainer {
    func makeAddSubscriptionViewModel() -> AddSubscriptionViewModel {
        AddSubscriptionViewModel(
            catalog: providerCatalog,
            saveRecurringItem: SaveRecurringItem(
                repository: repositories.recurringItems,
                notificationScheduler: notificationScheduler
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
                notificationScheduler: notificationScheduler
            ),
            deleteRecurringItem: DeleteRecurringItem(
                repository: repositories.recurringItems,
                notificationScheduler: notificationScheduler
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
