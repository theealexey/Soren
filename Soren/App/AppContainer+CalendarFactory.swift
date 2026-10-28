import Foundation

// MARK: - AppContainer + Calendar Factory

/// Composition root for the Calendar feature.
/// CalendarViewModel receives explicit persistence, preference, aggregation and FX dependencies.
extension AppContainer {
    func makeCalendarViewModel() -> CalendarViewModel {
        CalendarViewModel(
            repository: repositories.recurringItems,
            preferences: preferences,
            aggregateRecurringSpend: AggregateRecurringSpendUseCase(),
            exchangeRateProvider: exchangeRateProvider,
            timeZone: { .current }
        )
    }
}
