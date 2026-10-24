import Foundation
import SwiftData
import Testing
@testable import Soren

private enum CivilWiringFailure: Error { case bootstrap, validation, opening }

@MainActor
struct CivilDateStartupTests {
    @Test func malformedCustomCycleBlocksAndRetriesWithoutStoreMutation() throws {
        let container = try SorenModelContainer.inMemory()
        let row = try RecurringItemMapper.toSD(canonicalTestItem())
        row.billingCycleRaw = "custom:0"
        let originalDates = [row.startDate, row.nextChargeDate]
        let context = ModelContext(container)
        context.autosaveEnabled = false
        context.insert(row)
        try context.save()
        var opens = 0
        let state = AppState(openStore: { opens += 1; return container }, interpretationTimeZone: .gmt)
        for _ in 0..<2 {
            #expect(state.preparationState == .civilDateBlocked)
            #expect(state.appContainer == nil)
            #expect(state.modelContainer === container)
            #expect(state.preparationError as? BillingCycleEncoder.DecodingError == .invalidCustomCycle("custom:0"))
            state.recoverWithReset() // Blocked validation must not permit the store-reset path.
            let stored = try ModelContext(container).fetch(FetchDescriptor<SDRecurringItem>())
            let preserved = try #require(stored.first)
            #expect(stored.count == 1)
            #expect(preserved.billingCycleRaw == "custom:0")
            #expect([preserved.startDate, preserved.nextChargeDate] == originalDates)
            state.prepare()
        }
        #expect(opens == 1)
    }

    @Test func validatesSameRepositoryBeforePublication() throws {
        let container = try SorenModelContainer.inMemory()
        var order: [String] = []
        var validated: RepositoryContainer?
        let state = AppState(
            openStore: { order.append("open"); return container },
            interpretationTimeZone: .gmt,
            bootstrap: { _, _ in order.append("bootstrap") },
            validate: { repositories in
                order.append("validate")
                _ = try repositories.recurringItems.fetchAll()
                validated = repositories
            },
            makeAppContainer: { container, repositories in
                order.append("publish")
                return AppContainer(modelContext: container.mainContext, repositories: repositories)
            }
        )
        #expect(order == ["open", "bootstrap", "validate", "publish"])
        #expect(state.preparationState == .ready)
        #expect(state.appContainer?.repositories === validated)
    }

    @Test(arguments: [false, true])
    func retryPreservesContainerAndCapturedPolicy(validationFailure: Bool) throws {
        let container = try SorenModelContainer.inMemory()
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        var failing = true
        var opens = 0
        var policies: [String] = []
        var publications = 0
        let state = AppState(
            openStore: { opens += 1; return container }, interpretationTimeZone: zone,
            bootstrap: { container, timeZone in
                policies.append(timeZone.identifier)
                if failing && !validationFailure { throw CivilWiringFailure.bootstrap }
                try LegacyBillingDateProvenanceBootstrap().execute(container: container, interpretationTimeZone: timeZone)
            },
            validate: { repositories in
                _ = try repositories.recurringItems.fetchAll()
                if failing { throw CivilWiringFailure.validation }
            },
            makeAppContainer: { container, repositories in
                publications += 1
                return AppContainer(modelContext: container.mainContext, repositories: repositories)
            }
        )
        #expect(state.preparationState == .civilDateBlocked)
        #expect(state.appContainer == nil)
        #expect(state.preparationError != nil)
        #expect(state.modelContainer === container)
        #expect(publications == 0)
        failing = false
        state.prepare()
        #expect(state.preparationState == .ready)
        #expect(opens == 1)
        #expect(publications == 1)
        #expect(policies == [zone.identifier, zone.identifier])
    }

    @Test func realBootstrapAndValidationPreserveDatesAndExistingProvenance() throws {
        let container = try SorenModelContainer.inMemory()
        let first = try RecurringItemMapper.toSD(canonicalTestItem())
        first.billingDateEncodingVersion = nil
        first.startDate = first.startDate.addingTimeInterval(-7_200)
        first.nextChargeDate = first.nextChargeDate.addingTimeInterval(-7_200)
        let second = try RecurringItemMapper.toSD(canonicalTestItem())
        second.billingDateEncodingVersion = nil
        second.legacyBillingDateInterpretationTimeZoneIdentifier = "America/New_York"
        let dates = [first.startDate, first.nextChargeDate, second.startDate, second.nextChargeDate]
        let context = ModelContext(container)
        context.insert(first); context.insert(second); try context.save()
        let state = AppState(openStore: { container }, interpretationTimeZone: try #require(TimeZone(identifier: "Europe/Stockholm")))
        #expect(state.preparationState == .ready)
        let stored = try ModelContext(container).fetch(FetchDescriptor<SDRecurringItem>())
        #expect(stored.first(where: { $0.id == first.id })?.legacyBillingDateInterpretationTimeZoneIdentifier == "Europe/Stockholm")
        #expect(stored.first(where: { $0.id == second.id })?.legacyBillingDateInterpretationTimeZoneIdentifier == "America/New_York")
        #expect([first.startDate, first.nextChargeDate, second.startDate, second.nextChargeDate] == dates)
        state.prepare()
        #expect(state.preparationState == .ready)
        #expect(try state.appContainer?.repositories.recurringItems.fetchAll().count == 2)
    }

    @Test func unreadableRowBlocksWithoutPublishingOrDeleting() throws {
        let container = try SorenModelContainer.inMemory()
        let row = try RecurringItemMapper.toSD(canonicalTestItem())
        row.billingDateEncodingVersion = 99
        let context = ModelContext(container)
        context.insert(row); try context.save()
        let state = AppState(openStore: { container }, interpretationTimeZone: .gmt)
        #expect(state.preparationState == .civilDateBlocked)
        #expect(state.appContainer == nil)
        #expect(state.preparationError is RecurringItemBillingDateAdapterError)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SDRecurringItem>()) == 1)
    }

    @Test func openingFailureRemainsSeparate() {
        let state = AppState(openStore: { throw CivilWiringFailure.opening }, interpretationTimeZone: .gmt)
        #expect(state.preparationState == .storeUnavailable)
        #expect(state.modelContainer == nil)
        #expect(state.appContainer == nil)
    }

    @Test func retryWhileActiveReconcilesWithoutAnotherSceneTransition() async throws {
        let container = try SorenModelContainer.inMemory()
        let reconciler = CivilWiringReconciler()
        var failing = true
        let state = AppState(
            openStore: { container }, interpretationTimeZone: .gmt,
            validate: { repositories in
                _ = try repositories.recurringItems.fetchAll()
                if failing { throw CivilWiringFailure.validation }
            },
            makeAppContainer: { _, repositories in
                AppContainer(repositories: repositories, notificationReconciler: reconciler)
            }
        )
        state.sceneActivityChanged(isActive: true)
        #expect(reconciler.plans.isEmpty)
        failing = false
        state.prepare()
        let task = try #require(state.appContainer?.notificationRefreshCoordinator.refreshTask)
        await task.value
        #expect(reconciler.plans.count == 1)
    }
}

@MainActor
struct CivilDateFormInputTests {
    @Test(arguments: ["Europe/Stockholm", "America/Los_Angeles"])
    func calendarAnchorKeepsCivilDay(zoneID: String) throws {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = try #require(TimeZone(identifier: zoneID))
        let key = try CalendarViewModel.gridDay(for: canonicalTestDay(15), calendar: calendar)
        #expect(calendar.component(.year, from: key) == 2026)
        #expect(calendar.component(.month, from: key) == 8)
        #expect(calendar.component(.day, from: key) == 15)
    }

    @Test(arguments: ["Europe/Stockholm", "America/Los_Angeles", "Pacific/Auckland"])
    func pickerAndFormattingPreserveSemanticDay(zoneID: String) throws {
        let day = try CivilDate(year: 2026, month: 8, day: 15)
        let zone = try #require(TimeZone(identifier: zoneID))
        let carrier = try BillingDatePresentation.pickerCarrier(for: day, in: zone)
        #expect(try BillingDatePresentation.day(fromPickerCarrier: carrier, in: zone) == day)
        let canonical = try BillingCivilDay.canonicalDate(for: day)
        #expect(try BillingDatePresentation.string(from: canonical, locale: Locale(identifier: "en_US")) == "August 15")
        #expect(try BillingDatePresentation.string(from: canonical, locale: Locale(identifier: "ru_RU")).contains("15"))
        #expect(try BillingDatePresentation.string(from: canonical, locale: Locale(identifier: "ru_RU")).contains("августа"))
    }

    @Test func addEditNonDateAndStatusChangesKeepFullCanonicalTuple() async throws {
        let container = try SorenModelContainer.inMemory()
        let repositories = RepositoryContainer(context: container.mainContext)
        let suite = "CivilInput-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserPreferencesRepository(defaults: defaults)
        var zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let now = try canonicalTestDay(1)
        let vm = AddSubscriptionViewModel(
            catalog: InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repositories.recurringItems),
            preferences: preferences, currentDate: { now }, timeZone: { zone }
        )
        vm.title = "Civil day"
        vm.amountText = "100"
        let day = try CivilDate(year: 2026, month: 8, day: 15)
        let carrier = try BillingDatePresentation.pickerCarrier(for: day, in: zone)
        vm.startDate = try BillingDatePresentation.day(fromPickerCarrier: carrier, in: zone)
        vm.setNextChargeDateManually(day)
        vm.autoRenew = false
        vm.setEndDateManually(try CivilDate(year: 2026, month: 8, day: 20))
        zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        #expect(vm.nextChargeDate == day)
        #expect(try BillingDatePresentation.day(fromPickerCarrier: BillingDatePresentation.pickerCarrier(for: day, in: zone), in: zone) == day)
        try await vm.save()
        var item = try #require(repositories.recurringItems.fetchAll().first)
        #expect(item.nextChargeDate == (try BillingCivilDay.canonicalDate(for: day)))
        item.trialEndDate = try canonicalTestDay(16)
        try repositories.recurringItems.update(item)
        let edit = ItemDetailsViewModel(item: item, repositories: repositories, exchangeRateProvider: StaticExchangeRateProvider(), preferences: preferences, timeZone: { zone })
        edit.startEditing()
        #expect(edit.editNextChargeDate == day)
        #expect(edit.dateInputError == nil)
        edit.editTitle = "Renamed"
        try await edit.saveChanges()
        #expect(edit.item.nextChargeDate == item.nextChargeDate)
        #expect(edit.item.trialEndDate == item.trialEndDate)
        #expect(edit.item.endDate == item.endDate)
        try await edit.togglePause()
        try await edit.togglePause()
        try await edit.archive()
        #expect(edit.item.nextChargeDate == item.nextChargeDate)
        #expect(edit.nextScheduledChargeState == .notScheduled)
        #expect(edit.formattedNextCharge == String(localized: "itemDetails.nextScheduledCharge.notScheduled"))
    }
}

struct CivilDateNotificationBoundaryTests {
    @Test(arguments: ["Europe/Stockholm", "America/Los_Angeles"])
    func civilOccurrenceUsesSameLocalDayAndStableIdentity(zoneID: String) throws {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = try #require(TimeZone(identifier: zoneID))
        var item = try canonicalTestItem()
        item.chargeReminder = .sameDay
        item.trialReminder = .sameDay
        item.trialEndDate = item.nextChargeDate
        let plan = NotificationRequestPlanner(calendar: calendar, locale: Locale(identifier: "en_US")).plan(items: [item], now: try canonicalTestDay(1))
        #expect(plan.failures.isEmpty)
        #expect(plan.requests.count == 2)
        for request in plan.requests {
            #expect(request.trigger.day == 15)
            #expect(request.trigger.hour == 9)
            #expect(request.occurrenceLocalDateKey == "20260815")
            #expect(calendar.component(.day, from: request.fireDate) == 15)
            #expect(calendar.component(.hour, from: request.fireDate) == 9)
        }
    }

    @Test(arguments: [(2026, 3, 8), (2026, 11, 1), (2027, 1, 1), (2026, 9, 1)])
    func offsetsCrossBoundariesAndDST(parts: (Int, Int, Int)) throws {
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let day = try CivilDate(year: parts.0, month: parts.1, day: parts.2)
        var item = try canonicalTestItem()
        item.nextChargeDate = try BillingCivilDay.canonicalDate(for: day)
        item.startDate = item.nextChargeDate
        item.chargeReminder = .oneDayBefore
        let now = try #require(BillingCivilDay.calendar.date(byAdding: .day, value: -4, to: item.nextChargeDate))
        let plan = NotificationRequestPlanner(calendar: calendar, locale: Locale(identifier: "en_US")).plan(items: [item], now: now)
        let request = try #require(plan.requests.first)
        let expected = try #require(BillingCivilDay.calendar.date(byAdding: .day, value: -1, to: item.nextChargeDate))
        let expectedDay = try BillingCivilDay.civilDate(fromCanonicalDate: expected)
        #expect(request.trigger.year == expectedDay.year)
        #expect(request.trigger.month == expectedDay.month)
        #expect(request.trigger.day == expectedDay.day)
        #expect(calendar.component(.hour, from: request.fireDate) == 9)
    }
}

@MainActor
struct CivilDateNotificationRefreshTests {
    @Test func currentZoneIsResolvedAtEachReconciliation() async throws {
        let container = try SorenModelContainer.inMemory()
        let repositories = RepositoryContainer(context: container.mainContext)
        var item = try canonicalTestItem()
        item.chargeReminder = .sameDay
        try repositories.recurringItems.save(item)
        let reconciler = CivilWiringReconciler()
        let now = try canonicalTestDay(1)
        var zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let coordinator = NotificationRefreshCoordinator(
            repository: repositories.recurringItems, reconciler: reconciler,
            timeZone: { zone }, now: { now }
        )
        _ = await coordinator.reconcileCurrentState()
        zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        _ = await coordinator.reconcileCurrentState()
        let first = try #require(reconciler.plans.first?.requests.first)
        let second = try #require(reconciler.plans.last?.requests.first)
        #expect(first.id == second.id)
        #expect(first.fireDate != second.fireDate)
        var calendar = BillingCivilDay.calendar
        calendar.timeZone = zone
        #expect(calendar.component(.day, from: second.fireDate) == 15)
        #expect(calendar.component(.hour, from: second.fireDate) == 9)
    }

    @Test func invalidPersistedRowDoesNotReconcileDestructiveEmptyPlan() async throws {
        let container = try SorenModelContainer.inMemory()
        let row = try RecurringItemMapper.toSD(canonicalTestItem())
        row.billingDateEncodingVersion = 99
        let context = ModelContext(container)
        context.insert(row)
        try context.save()
        let repositories = RepositoryContainer(context: container.mainContext)
        let reconciler = CivilWiringReconciler()
        let coordinator = NotificationRefreshCoordinator(repository: repositories.recurringItems, reconciler: reconciler)
        #expect(await coordinator.reconcileCurrentState() == .repositoryFetchFailed)
        #expect(coordinator.lastRepositoryError is RecurringItemBillingDateAdapterError)
        #expect(reconciler.plans.isEmpty)
    }
}

@MainActor
private final class CivilWiringReconciler: NotificationReconciling {
    var plans: [NotificationRequestPlan] = []
    func reconcile(plan: NotificationRequestPlan) async -> NotificationReconciliationReport {
        plans.append(plan)
        return NotificationReconciliationReport(desiredCount: plan.requests.count, removedPendingCount: 0, removedDeliveredCount: 0, addedCount: plan.requests.count, authorizationStatus: .authorized, addFailures: [], planningFailures: plan.failures)
    }
}
