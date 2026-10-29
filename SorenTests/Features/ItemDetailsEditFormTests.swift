import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - ItemDetailsViewModel Edit Form Tests
//
// Covers the device-reproducible bug:
//   Open Edit form → startDate == Apr 24 / nextCharge == May 24.
//   Change startDate to Mar 24 → nextCharge must become Apr 24 (today).
//
// And the manual-override contract:
//   Once the user picks a next-charge date in this session, later startDate
//   changes must not overwrite it.

@Suite("ItemDetailsViewModel — edit form nextChargeDate")
@MainActor
struct ItemDetailsEditFormTests {
    @Test("Derived normalized costs retain errors, original amount and edit capability, then recover")
    func normalizationFailureRecovers() throws {
        let anchor = todayStartOfDay
        let source = makeItem(startDate: anchor, nextChargeDate: anchor)
        let repositories = try makeRepositories()
        try repositories.recurringItems.save(source)
        let vm = ItemDetailsViewModel(item: source, repositories: repositories,
            exchangeRateProvider: StaticExchangeRateProvider(), now: { anchor }, timeZone: { .gmt })
        #expect(vm.normalizedMonthlyAmount == 299)
        #expect(vm.normalizedAnnualAmount == 3588)
        vm.item.billingCycle = .custom(days: -1)
        #expect(vm.normalizationError as? BillingCycle.ValidationError == .invalidCustomDays(-1))
        #expect(vm.normalizedMonthlyAmount == nil)
        #expect(vm.normalizedAnnualAmount == nil)
        #expect(vm.item.amount == source.amount)
        vm.startEditing()
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: anchor)))
        #expect(try repositories.recurringItems.fetch(id: source.id) == source)
        vm.item.billingCycle = .annual
        #expect(vm.normalizationError == nil)
        #expect(vm.normalizedAnnualAmount == 299)
        #expect(vm.normalizedMonthlyAmount == Decimal(299) / 12)
        #expect(vm.nextScheduledChargeState == .scheduled(try BillingCivilDay.civilDate(fromCanonicalDate: anchor)))
    }

    // MARK: - Helpers

    private func makeRepositories() throws -> RepositoryContainer {
        let container = try SorenModelContainer.inMemory()
        return RepositoryContainer(context: container.mainContext)
    }

    private func makeItem(
        startDate: Date,
        nextChargeDate: Date,
        cycle: BillingCycle = .monthly
    ) -> RecurringItem {
        RecurringItem(
            title: "Test",
            providerName: "Test",
            itemType: .subscription,
            category: .other,
            amount: 299,
            currencyCode: "RUB",
            billingCycle: cycle,
            startDate: startDate,
            nextChargeDate: nextChargeDate,
            autoRenew: true,
            chargeReminder: .threeDaysBefore,
            status: .active,
            usageStatus: .unknown
        )
    }

    /// Today's calendar day at 00:00 (stable across the test run).
    private var todayStartOfDay: Date {
        Date(timeIntervalSince1970: 1_786_752_000) // 2026-08-15 UTC
    }

    // MARK: - Recompute on startDate change

    @Test("Details projects November while Edit preserves the October anchor")
    func projectedDisplayPreservesEditAnchor() async throws {
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        let reference = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 21))
        let source = makeItem(startDate: anchor, nextChargeDate: anchor)
        let repositories = try makeRepositories()
        try repositories.recurringItems.save(source)
        var clockReads = 0
        let vm = ItemDetailsViewModel(
            item: source, repositories: repositories, exchangeRateProvider: StaticExchangeRateProvider(),
            now: { clockReads += 1; return reference }, timeZone: { .gmt }
        )
        let expected = try CivilDate(year: 2026, month: 11, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(expected))
        #expect(vm.nextScheduledChargeError == nil)
        #expect(vm.formattedNextCharge == (try BillingDatePresentation.string(
            from: BillingCivilDay.canonicalDate(for: expected))))
        let reads = clockReads
        _ = vm.formattedNextCharge
        _ = vm.nextScheduledChargeState
        #expect(clockReads == reads)
        #expect(try repositories.recurringItems.fetch(id: source.id)?.nextChargeDate == anchor)
        vm.startEditing()
        let anchorDay = try CivilDate(year: 2026, month: 10, day: 15)
        #expect(vm.editNextChargeDate == anchorDay)
        vm.editTitle = "Renamed"
        try await vm.saveChanges()
        #expect(vm.item.nextChargeDate == anchor)
        #expect(try repositories.recurringItems.fetch(id: source.id)?.nextChargeDate == anchor)
        #expect(vm.nextScheduledChargeState == .scheduled(expected))
    }

    @Test("Unavailable projection retains error and differs from absence")
    func unavailableDisplayRetainsDiagnostic() throws {
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        var source = makeItem(startDate: anchor, nextChargeDate: anchor)
        source.status = .trial
        let vm = ItemDetailsViewModel(
            item: source, repositories: try makeRepositories(), exchangeRateProvider: StaticExchangeRateProvider(),
            now: { anchor }, timeZone: { .gmt }
        )
        #expect(vm.nextScheduledChargeState == .unavailable)
        #expect(vm.nextScheduledChargeError as? RecurringScheduleProjectionError == .monetaryScheduleUnavailable)
        #expect(vm.formattedNextCharge == String(localized: "itemDetails.nextScheduledCharge.unavailable"))
        vm.item.status = .paused
        #expect(vm.nextScheduledChargeState == .notScheduled)
        #expect(vm.nextScheduledChargeError == nil)
        #expect(vm.formattedNextCharge == String(localized: "itemDetails.nextScheduledCharge.notScheduled"))
        vm.item.status = .active
        let anchorDay = try CivilDate(year: 2026, month: 10, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(anchorDay))
    }

    @Test("Same explicit local today projects the same civil date", arguments: [
        "Europe/Stockholm", "America/Los_Angeles", "Asia/Tokyo"
    ])
    func scheduledDisplayTimezoneStability(_ zoneID: String) throws {
        let zone = try #require(TimeZone(identifier: zoneID))
        let today = try CivilDate(year: 2026, month: 10, day: 21)
        let now = try BillingDatePresentation.pickerCarrier(for: today, in: zone)
        let anchor = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        let vm = ItemDetailsViewModel(
            item: makeItem(startDate: anchor, nextChargeDate: anchor), repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(), now: { now }, timeZone: { zone }
        )
        #expect(vm.today == today)
        let expectedDay = try CivilDate(year: 2026, month: 11, day: 15)
        #expect(vm.nextScheduledChargeState == .scheduled(expectedDay))
    }

    @Test("Changing startDate applies the calendar-aware automatic monthly suggestion")
    func changingStartDateRecomputesNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let oneMonthFromToday = try #require(
            cal.date(byAdding: .month, value: 1, to: today)
        )
        let stored = makeItem(startDate: today, nextChargeDate: oneMonthFromToday)

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // Seed preserved: next-charge stayed at the stored value.
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthFromToday)))

        // Use the first of the month so calendar clamping at days 29–31 cannot
        // change the intended billing occurrence. The VM owns the current-day
        // lookup; its pure date arithmetic is covered with fixed UTC dates by
        // NextChargeDateSuggestionTests.
        let currentMonth = try #require(cal.dateInterval(of: .month, for: today))
        let firstOfCurrentMonth = currentMonth.start
        let previousMonthFirst = try #require(
            cal.date(byAdding: .month, value: -1, to: firstOfCurrentMonth)
        )
        let expectedNextChargeDate = if cal.isDate(today, inSameDayAs: firstOfCurrentMonth) {
            firstOfCurrentMonth
        } else {
            try #require(
                cal.date(byAdding: .month, value: 1, to: firstOfCurrentMonth)
            )
        }

        vm.editStartDate = try BillingCivilDay.civilDate(fromCanonicalDate: previousMonthFirst)

        // A selected relationship start date is never reused as the next charge.
        // The next charge is the first monthly occurrence on or after today.
        #expect(
            vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: expectedNextChargeDate)),
            "Expected \(expectedNextChargeDate), got \(vm.editNextChargeDate)"
        )
    }

    @Test("Changing billingCycle recomputes nextChargeDate when not manually overridden")
    func changingBillingCycleRecomputesNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let oneYearFromToday = cal.date(byAdding: .year, value: 1, to: today)!
        // Stored as annual so the seeded next-charge is far enough out that a
        // monthly recompute produces a clearly different calendar day.
        let stored = makeItem(
            startDate: today,
            nextChargeDate: oneYearFromToday,
            cycle: .annual
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneYearFromToday)))

        // User switches cycle to monthly → nextCharge should recompute.
        vm.editBillingCycle = .monthly

        // startDate == today, monthly → suggest() advances one month (today not in past).
        let oneMonthFromToday = cal.date(byAdding: .month, value: 1, to: today)!
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthFromToday)))
    }

    // MARK: - Manual override

    @Test("After manual nextChargeDate pick, startDate changes do not overwrite it")
    func manualOverrideBlocksRecompute() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // User explicitly picks a specific next-charge date far in the future.
        let userPick = cal.date(byAdding: .day, value: 45, to: today)!
        vm.setEditNextChargeDateManually(try BillingCivilDay.civilDate(fromCanonicalDate: userPick))
        #expect(vm.isEditNextChargeDateManuallySet)

        // Later, user changes startDate — must NOT overwrite the manual pick.
        let oneMonthAgo = cal.date(byAdding: .month, value: -1, to: today)!
        vm.editStartDate = try BillingCivilDay.civilDate(fromCanonicalDate: oneMonthAgo)

        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: userPick)))
    }

    @Test("After manual nextChargeDate pick, billingCycle changes do not overwrite it")
    func manualOverrideBlocksCycleRecompute() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: today,
            nextChargeDate: cal.date(byAdding: .month, value: 1, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        let userPick = cal.date(byAdding: .day, value: 100, to: today)!
        vm.setEditNextChargeDateManually(try BillingCivilDay.civilDate(fromCanonicalDate: userPick))

        vm.editBillingCycle = .annual

        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: userPick)))
    }

    // MARK: - Seed integrity

    @Test("startEditing seeds nextChargeDate exactly to the stored value")
    func startEditingSeedsStoredNextCharge() throws {
        let cal = BillingCivilDay.calendar
        let today = todayStartOfDay
        let stored = makeItem(
            startDate: cal.date(byAdding: .day, value: -10, to: today)!,
            nextChargeDate: cal.date(byAdding: .day, value: 20, to: today)!
        )

        let vm = ItemDetailsViewModel(
            item: stored,
            repositories: try makeRepositories(),
            exchangeRateProvider: StaticExchangeRateProvider(),
            now: { self.todayStartOfDay }, timeZone: { .gmt }
        )
        vm.startEditing()

        // Seed must not be clobbered by the billingCycle/startDate didSets that
        // fire during assignment inside startEditing().
        #expect(vm.editNextChargeDate == (try BillingCivilDay.civilDate(fromCanonicalDate: stored.nextChargeDate)))
        // Manual-override flag must be released after seed so later edits
        // engage the auto-suggest path.
        #expect(vm.isEditNextChargeDateManuallySet == false)
    }
}

// MARK: - Details action failure contract

@Suite("Item Details action failures")
@MainActor
struct ItemDetailsActionFailureTests {
    private func item(status: ItemStatus = .active) throws -> RecurringItem {
        let day = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 15))
        return RecurringItem(title: "Original", amount: 100, startDate: day, nextChargeDate: day, status: status)
    }

    private func model(_ source: RecurringItem, repository: DetailsActionRepository,
                       coordinator: DetailsActionNotifications? = nil,
                       now: (() -> Date)? = nil,
                       timeZone: @escaping () -> TimeZone = { .gmt }) -> ItemDetailsViewModel {
        ItemDetailsViewModel(
            item: source,
            updateRecurringItem: UpdateRecurringItem(repository: repository, notificationCoordinator: coordinator),
            deleteRecurringItem: DeleteRecurringItem(repository: repository, notificationCoordinator: coordinator),
            currencyEstimateService: CurrencyEstimateService(exchangeRateProvider: StaticExchangeRateProvider(), convertMoney: ConvertMoneyUseCase()),
            notificationCoordinator: coordinator,
            preferences: UserPreferencesRepository(), now: now ?? { source.startDate }, timeZone: timeZone
        )
    }

    @Test("Persistence failure preserves the complete edit draft and retry saves it")
    func saveFailureAndRetry() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        repository.rejectMutation = true
        let vm = model(source, repository: repository)
        vm.startEditing()
        vm.editTitle = "Retained draft"
        vm.editAmountText = "234,50"
        vm.editNote = "Retained note"
        let start = vm.editStartDate
        let next = vm.editNextChargeDate
        await #expect(throws: DetailsActionRepository.Failure.self) { try await vm.saveChanges() }
        #expect(vm.item == source)
        #expect(repository.stored == source)
        #expect(vm.editTitle == "Retained draft")
        #expect(vm.editAmountText == "234,50")
        #expect(vm.editNote == "Retained note")
        #expect(vm.editStartDate == start && vm.editNextChargeDate == next)
        #expect(vm.isEditing && !vm.isPerformingAction && !vm.isDeleted)
        #expect(vm.actionFailure?.intent == .save)
        #expect(vm.actionFailure?.canRetry == true)
        repository.rejectMutation = false
        #expect(try await vm.retryFailedAction())
        #expect(vm.item.title == "Retained draft" && vm.item.note == "Retained note")
        #expect(vm.item.amount == Decimal(string: "234.50"))
        #expect(repository.stored == vm.item)
        #expect(!vm.isEditing && vm.actionFailure == nil)
    }

    @Test("Invalid input does not write or offer blind retry")
    func validationFailure() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let vm = model(source, repository: repository)
        vm.startEditing()
        vm.editTitle = " "
        await #expect(throws: UpdateRecurringItem.ValidationError.emptyTitle) { try await vm.saveChanges() }
        #expect(repository.updateCalls == 0)
        #expect(vm.item == source && vm.isEditing)
        #expect(vm.actionFailure?.kind == .invalidInput)
        #expect(vm.actionFailure?.message == ValidationErrorFormatter.localizedMessage(for: UpdateRecurringItem.ValidationError.emptyTitle))
        #expect(try await vm.retryFailedAction() == false)
    }

    @Test("Missing update never reports success or offers retry")
    func missingRecord() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        repository.stored = nil
        let vm = model(source, repository: repository)
        vm.startEditing()
        await #expect(throws: RepositoryError.self) { try await vm.saveChanges() }
        #expect(vm.item == source && vm.isEditing && !vm.isDeleted)
        #expect(vm.actionFailure?.kind == .missingRecord)
        #expect(vm.actionFailure?.canRetry == false)
        #expect(try await vm.retryFailedAction() == false)
    }

    @Test("Failed status/delete actions preserve visible state", arguments: [
        ItemDetailsViewModel.ActionIntent.pause, .resume, .archive, .delete
    ])
    func failedAction(_ intent: ItemDetailsViewModel.ActionIntent) async throws {
        let source = try item(status: intent == .resume ? .paused : .active)
        let repository = DetailsActionRepository(source)
        repository.rejectMutation = true
        let vm = model(source, repository: repository)
        await #expect(throws: DetailsActionRepository.Failure.self) { try await vm.perform(intent) }
        #expect(vm.item == source && repository.stored == source)
        #expect(!vm.isDeleted && !vm.hasPersistedDeletion && !vm.isPerformingAction)
        #expect(vm.actionFailure?.intent == intent)
        #expect(vm.actionFailure?.canRetry == true)
        repository.rejectMutation = false
        #expect(try await vm.retryFailedAction())
        switch intent {
        case .pause: #expect(vm.item.status == .paused)
        case .resume: #expect(vm.item.status == .active)
        case .archive: #expect(vm.item.status == .archived)
        case .delete: #expect(vm.isDeleted)
        case .save: Issue.record("Unexpected test intent")
        }
    }

    @Test("Saved actions retain partial reminder outcome and retry only notifications", arguments: [
        ItemDetailsViewModel.ActionIntent.pause, .save, .delete
    ])
    func partialOutcome(_ intent: ItemDetailsViewModel.ActionIntent) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .repositoryFetchFailed
        let vm = model(source, repository: repository, coordinator: notifications)
        if intent == .save { vm.startEditing(); vm.editTitle = "Saved draft" }
        #expect(try await vm.perform(intent))
        #expect(vm.actionFailure == nil && vm.reminderIssue == .reconciliation)
        #expect(vm.canRetryReminders && !vm.isPerformingAction)
        #expect(repository.updateCalls + repository.deleteCalls == 1)
        let saved = repository.stored
        if intent == .save {
            #expect(vm.item.title == "Saved draft" && !vm.isEditing)
            #expect(!vm.canPresentDetailsAlert)
            vm.editSheetDidDismiss()
            #expect(vm.canPresentDetailsAlert)
        }
        if intent == .pause { #expect(vm.item.status == .paused) }
        if intent == .delete {
            #expect(repository.stored == nil && vm.hasPersistedDeletion && !vm.isDeleted)
            #expect(vm.preventsDismissal && vm.mutationsDisabled)
            #expect(try await vm.perform(.delete) == false)
        }
        // A second reminder failure preserves the authoritative persisted outcome.
        #expect(await vm.retryReminders())
        #expect(vm.reminderIssue == .reconciliation && !vm.isDeleted)
        notifications.outcome = DetailsActionNotifications.success
        #expect(await vm.retryReminders())
        #expect(repository.stored == saved) // includes unchanged updatedAt
        #expect(repository.updateCalls + repository.deleteCalls == 1)
        #expect(notifications.sources == [intent == .delete ? .delete : .update, .other, .other])
        #expect(vm.reminderIssue == nil && !vm.isPerformingAction)
        if intent == .delete {
            #expect(vm.isDeleted && !vm.preventsDismissal)
            #expect(await vm.retryReminders() == false)
            #expect(try await vm.perform(.delete) == false)
        }
    }

    @Test("Post-delete acknowledgment releases dismissal without another delete")
    func acknowledgeDeletedWarning() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .repositoryFetchFailed
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.delete())
        #expect(vm.hasPersistedDeletion && !vm.isDeleted)
        vm.acknowledgeReminderIssue()
        #expect(vm.isDeleted && !vm.preventsDismissal)
        vm.acknowledgeReminderIssue()
        #expect(try await vm.delete() == false)
        #expect(repository.deleteCalls == 1 && notifications.sources == [.delete])
    }

    @Test("An absent ID is still an idempotent successful delete")
    func absentDelete() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        repository.stored = nil
        let vm = model(source, repository: repository)
        #expect(try await vm.delete())
        #expect(vm.isDeleted && vm.actionFailure == nil)
        #expect(repository.deleteCalls == 1)
    }

    @Test("The common gate rejects competing mutations while reconciliation is suspended", arguments: [
        ItemDetailsViewModel.ActionIntent.pause, .save, .delete
    ])
    func overlappingActions(_ intent: ItemDetailsViewModel.ActionIntent) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.suspend = true
        let vm = model(source, repository: repository, coordinator: notifications)
        if intent == .save { vm.startEditing(); vm.editTitle = "Draft" }
        let first = Task { try await vm.perform(intent) }
        await notifications.started.wait()
        #expect(vm.isPerformingAction && vm.preventsDismissal)
        #expect(repository.updateCalls + repository.deleteCalls == 1)
        #expect(try await vm.perform(intent == .pause ? .archive : intent) == false)
        #expect(await vm.retryReminders() == false)
        vm.cancelEditing()
        if intent == .save { #expect(vm.isEditing) }
        #expect(vm.actionFailure == nil && !vm.isDeleted)
        #expect(notifications.sources.count == 1)
        // Cancellation after persistence does not discard its eventual result.
        first.cancel()
        notifications.finish()
        #expect(try await first.value)
        #expect(!vm.isPerformingAction)
        if intent == .delete { #expect(vm.isDeleted) }
        if intent == .pause { #expect(vm.item.status == .paused) }
        if intent == .save { #expect(vm.item.title == "Draft" && !vm.isEditing) }
        #expect(repository.updateCalls + repository.deleteCalls == 1)
    }

    @Test("An attempt cancelled before it starts does not write or remain busy")
    func cancelledBeforeStart() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let vm = model(source, repository: repository)
        let gate = NotificationTestGate()
        let task = Task { await gate.wait(); return try await vm.perform(.pause) }
        task.cancel()
        gate.signal()
        #expect(try await task.value == false)
        #expect(!vm.isPerformingAction && vm.actionFailure == nil)
        #expect(repository.updateCalls == 0)
    }

    @Test("Permission warnings depend on the complete plan's demand", arguments: [
        NotificationAuthorizationStatus.denied, .notDetermined
    ], [0, 1])
    func permissions(_ status: NotificationAuthorizationStatus, _ desiredCount: Int) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .reconciled(.init(desiredCount: desiredCount, removedPendingCount: 0,
            removedDeliveredCount: 0, addedCount: 0, authorizationStatus: status, addFailures: [], planningFailures: []))
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.perform(.delete))
        #expect(vm.actionFailure == nil)
        #expect(vm.reminderIssue == (desiredCount > 0 ? .permission : nil))
        #expect(!vm.canRetryReminders)
        #expect(vm.isDeleted == (desiredCount == 0))
        if desiredCount > 0 {
            #expect(vm.reminderMessage.contains(String(localized: "itemDetails.reminders.permission")))
            vm.acknowledgeReminderIssue()
            #expect(vm.isDeleted)
        }
    }

    @Test("Add failures warn without implying this specific item's reminder failed")
    func addFailure() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .reconciled(.init(desiredCount: 1, removedPendingCount: 0, removedDeliveredCount: 0,
            addedCount: 0, authorizationStatus: .authorized, addFailures: [.addFailed(identifier: "another-item")], planningFailures: []))
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.perform(.pause))
        #expect(vm.reminderIssue == .reconciliation && vm.canRetryReminders)
        #expect(vm.actionFailure == nil && repository.stored?.status == .paused)
    }

    @Test("Superseded and absent coordinators do not assert scheduling success", arguments: [false, true])
    func unconfirmedOutcome(_ hasCoordinator: Bool) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = hasCoordinator ? DetailsActionNotifications() : nil
        notifications?.outcome = .superseded
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.delete())
        #expect(vm.lastNotificationOutcome == (hasCoordinator ? .superseded : nil))
        #expect(vm.actionFailure == nil && vm.reminderIssue == nil && !vm.canRetryReminders)
        #expect(vm.isDeleted)
    }

    @Test("Superseded retry retains the unresolved warning")
    func supersededRetry() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .repositoryFetchFailed
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.delete())
        notifications.outcome = .superseded
        #expect(await vm.retryReminders())
        #expect(vm.reminderIssue == .reconciliation && !vm.isDeleted)
        #expect(repository.deleteCalls == 1)
        vm.acknowledgeReminderIssue()
        #expect(vm.isDeleted)
    }

    @Test("Terminal lifecycle rejects both status intents without side effects", arguments: [
        "archived", "archivedWithDate", "cancelled", "activeWithArchiveDate", "pausedWithArchiveDate",
        "endedActive", "endedPaused"
    ], [ItemDetailsViewModel.ActionIntent.pause, .resume])
    func terminalStatusActions(scenario: String, intent: ItemDetailsViewModel.ActionIntent) async throws {
        var source = try item()
        let reference = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2026, month: 10, day: 16))
        switch scenario {
        case "archived": source.status = .archived
        case "archivedWithDate": source.status = .archived; source.archivedAt = source.startDate
        case "cancelled": source.status = .cancelled
        case "activeWithArchiveDate": source.archivedAt = source.startDate
        case "pausedWithArchiveDate": source.status = .paused; source.archivedAt = source.startDate
        case "endedActive", "endedPaused":
            source.status = scenario == "endedPaused" ? .paused : .active
            source.autoRenew = false
            source.endDate = source.startDate
        default: Issue.record("Unexpected test scenario")
        }
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        let vm = model(source, repository: repository, coordinator: notifications, now: { reference })
        #expect(vm.pauseResumeIntent == nil)
        #expect(try await vm.perform(intent) == false)
        #expect(try await vm.togglePause() == false)
        #expect(vm.item == source && repository.stored == source)
        #expect(repository.updateCalls == 0 && repository.deleteCalls == 0)
        #expect(notifications.sources.isEmpty)
        #expect(vm.actionFailure == nil && vm.reminderIssue == nil)
        #expect(!vm.isPerformingAction && !vm.isDeleted && !vm.hasPersistedDeletion)
        #expect(!vm.isEditing && !vm.preventsDismissal)
    }

    @Test("Current statuses preserve their explicit action eligibility", arguments: ItemStatus.allCases)
    func statusEligibility(status: ItemStatus) throws {
        let source = try item(status: status)
        let vm = model(source, repository: DetailsActionRepository(source))
        let expected: ItemDetailsViewModel.ActionIntent?
        switch status {
        case .active, .dueSoon, .dueToday, .overdue, .trial, .failed: expected = .pause
        case .paused: expected = .resume
        case .archived, .cancelled: expected = nil
        }
        #expect(vm.pauseResumeIntent == expected)
    }

    @Test("The finite end day is inclusive and normal pause/resume still works", arguments: [false, true])
    func inclusiveEndAndRoundTrip(finite: Bool) async throws {
        var source = try item()
        source.autoRenew = !finite
        source.endDate = finite ? source.startDate : nil
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(vm.pauseResumeIntent == .pause)
        #expect(try await vm.perform(.resume) == false)
        #expect(try await vm.perform(.pause))
        #expect(vm.item.status == .paused && vm.pauseResumeIntent == .resume)
        #expect(try await vm.perform(.pause) == false)
        #expect(try await vm.perform(.resume))
        #expect(vm.item.status == .active && vm.pauseResumeIntent == .pause)
        #expect(vm.item.endDate == source.endDate && vm.item.autoRenew == source.autoRenew)
        #expect(repository.updateCalls == 2 && notifications.sources == [.update, .update])
        #expect(vm.actionFailure == nil && !vm.isPerformingAction)
    }

    @Test("Eligibility uses the injected local civil day rather than a canonical instant")
    func eligibilityUsesTimeZone() async throws {
        var source = try item()
        source.autoRenew = false
        source.endDate = source.startDate
        let instant = try #require(ISO8601DateFormatter().date(from: "2026-10-16T01:00:00Z"))
        var zone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        let vm = model(source, repository: repository, coordinator: notifications, now: { instant }, timeZone: { zone })
        #expect(vm.today == (try CivilDate(year: 2026, month: 10, day: 15)))
        #expect(vm.pauseResumeIntent == .pause)
        zone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        #expect(vm.today == (try CivilDate(year: 2026, month: 10, day: 16)))
        #expect(vm.pauseResumeIntent == nil)
        #expect(try await vm.perform(.pause) == false)
        #expect(repository.updateCalls == 0 && notifications.sources.isEmpty)
    }

    @Test("Unknown civil today or malformed finite end date fails closed", arguments: [false, true])
    func invalidCivilEvaluation(invalidClock: Bool) async throws {
        var source = try item()
        source.autoRenew = false
        source.endDate = invalidClock ? source.startDate : source.startDate.addingTimeInterval(1)
        let instant = invalidClock ? Date(timeIntervalSince1970: .infinity) : source.startDate
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        let vm = model(source, repository: repository, coordinator: notifications, now: { instant })
        #expect(vm.pauseResumeIntent == nil)
        #expect(try await vm.perform(.pause) == false)
        #expect(try await vm.perform(.resume) == false)
        #expect(vm.item == source && repository.stored == source)
        #expect(repository.updateCalls == 0 && notifications.sources.isEmpty)
        #expect(vm.actionFailure == nil && !vm.isPerformingAction && !vm.isDeleted)
    }

    @Test("Resolved archive reminder warning never restores pause eligibility")
    func archiveStaysTerminalAfterWarning() async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .repositoryFetchFailed
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.archive())
        #expect(vm.reminderIssue == .reconciliation)
        notifications.outcome = DetailsActionNotifications.success
        #expect(await vm.retryReminders())
        #expect(vm.reminderIssue == nil && vm.pauseResumeIntent == nil)
        vm.acknowledgeReminderIssue()
        let archived = vm.item
        #expect(archived.status == .archived && archived.archivedAt != nil)
        #expect(try await vm.perform(.pause) == false)
        #expect(try await vm.perform(.resume) == false)
        #expect(vm.item == archived && repository.stored == archived)
        #expect(repository.updateCalls == 1 && notifications.sources == [.update, .other])
        #expect(!vm.isPerformingAction && vm.actionFailure == nil)
    }

    @Test("Retained retry rechecks the current lifecycle before another write", arguments: [
        ItemDetailsViewModel.ActionIntent.pause, .resume
    ])
    func failedActionCannotBypassEligibility(intent: ItemDetailsViewModel.ActionIntent) async throws {
        let source = try item(status: intent == .resume ? .paused : .active)
        let repository = DetailsActionRepository(source)
        repository.rejectMutation = true
        let notifications = DetailsActionNotifications()
        let vm = model(source, repository: repository, coordinator: notifications)
        await #expect(throws: DetailsActionRepository.Failure.self) { try await vm.perform(intent) }
        #expect(vm.actionFailure?.canRetry == true)
        var archived = source
        archived.status = .archived
        archived.archivedAt = source.startDate
        vm.item = archived
        repository.stored = archived
        repository.rejectMutation = false
        #expect(try await vm.retryFailedAction() == false)
        #expect(repository.updateCalls == 1 && notifications.sources.isEmpty)
        #expect(vm.item == archived && repository.stored == archived)
        #expect(vm.actionFailure?.intent == intent)
        #expect(!vm.isPerformingAction && !vm.isDeleted)
    }

}

@MainActor
private final class DetailsActionNotifications: NotificationStateReconciling {
    static var success: NotificationRefreshOutcome {
        .reconciled(.init(desiredCount: 0, removedPendingCount: 0, removedDeliveredCount: 0, addedCount: 0,
                          authorizationStatus: .authorized, addFailures: [], planningFailures: []))
    }
    var outcome = DetailsActionNotifications.success
    var sources: [NotificationReconciliationSource] = []
    var suspend = false
    let started = NotificationTestGate()
    private var continuation: CheckedContinuation<Void, Never>?

    func reconcileCurrentState(source: NotificationReconciliationSource) async -> NotificationRefreshOutcome {
        sources.append(source)
        if suspend {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                started.signal()
            }
        }
        return outcome
    }

    func finish() {
        let pending = continuation
        continuation = nil
        suspend = false
        pending?.resume()
    }
}

@MainActor
private final class DetailsActionRepository: RecurringItemRepository {
    enum Failure: Error { case rejected }
    var stored: RecurringItem?
    var rejectMutation = false
    private(set) var updateCalls = 0
    private(set) var deleteCalls = 0
    init(_ item: RecurringItem) { stored = item }
    func fetchAll() throws -> [RecurringItem] { stored.map { [$0] } ?? [] }
    func fetchActive() throws -> [RecurringItem] { try fetchAll().filter { $0.status.countsInTotals } }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { try fetchAll().filter { $0.category == category } }
    func fetch(id: UUID) throws -> RecurringItem? { stored?.id == id ? stored : nil }
    func save(_ item: RecurringItem) throws { stored = item }
    func update(_ item: RecurringItem) throws {
        updateCalls += 1
        if rejectMutation { throw Failure.rejected }
        guard stored?.id == item.id else { throw RepositoryError.notFound(item.id) }
        stored = item
    }
    func delete(id: UUID) throws {
        deleteCalls += 1
        if rejectMutation { throw Failure.rejected }
        if stored?.id == id { stored = nil }
    }
    func saveAll(_ items: [RecurringItem]) throws { stored = items.first }
    func deleteAll() throws { stored = nil }
}

extension ItemDetailsActionFailureTests {
    @Test("Scheduling-only issues warn after persistence and notification-only retries never repeat the mutation", arguments: ["capacity", "missing"], [
        ItemDetailsViewModel.ActionIntent.save, .pause, .archive, .delete
    ])
    func schedulingOutcomeRetry(issue: String, intent: ItemDetailsViewModel.ActionIntent) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        let identifier = "soren.v2.renewalDecision.item.20261112.0"
        let report = NotificationReconciliationReport(desiredCount: 1, removedPendingCount: 0,
            removedDeliveredCount: 0, addedCount: issue == "missing" ? 1 : 0,
            authorizationStatus: .authorized, addFailures: [], planningFailures: [],
            capacityOmittedIdentifiers: issue == "capacity" ? [identifier] : [],
            missingPendingIdentifiers: issue == "missing" ? [identifier] : [], pendingCountAfterReconciliation: 0)
        notifications.outcome = .reconciled(report)
        let vm = model(source, repository: repository, coordinator: notifications)
        if intent == .save { vm.startEditing(); vm.editTitle = "Persisted edit" }
        #expect(try await vm.perform(intent))
        let persisted = repository.stored
        let published = vm.item
        #expect(vm.reminderIssue == .reconciliation && vm.isReminderAlertPresented && vm.canRetryReminders)
        #expect(vm.actionFailure == nil && !vm.isPerformingAction)
        #expect(repository.updateCalls == (intent == .delete ? 0 : 1))
        #expect(repository.deleteCalls == (intent == .delete ? 1 : 0))
        switch intent {
        case .save:
            #expect(vm.item.title == "Persisted edit" && !vm.isEditing)
            vm.editSheetDidDismiss()
            #expect(vm.canPresentDetailsAlert)
        case .pause: #expect(vm.item.status == .paused)
        case .archive: #expect(vm.item.status == .archived && vm.item.archivedAt != nil)
        case .delete: #expect(persisted == nil && vm.hasPersistedDeletion && !vm.isDeleted && vm.preventsDismissal)
        case .resume: Issue.record("Unexpected test intent")
        }
        #expect(await vm.retryReminders())
        #expect(vm.reminderIssue == .reconciliation && vm.isReminderAlertPresented)
        #expect(repository.stored == persisted && vm.item == published && !vm.isDeleted)
        notifications.outcome = .reconciled(.init(desiredCount: 1, removedPendingCount: 0,
            removedDeliveredCount: 0, addedCount: 1, authorizationStatus: .authorized,
            addFailures: [], planningFailures: [], pendingCountAfterReconciliation: 1))
        #expect(await vm.retryReminders())
        #expect(vm.reminderIssue == nil && !vm.isReminderAlertPresented && !vm.isPerformingAction)
        #expect(repository.stored == persisted && vm.item == published)
        #expect(repository.updateCalls + repository.deleteCalls == 1)
        #expect(notifications.sources == [intent == .delete ? .delete : .update, .other, .other])
        #expect(vm.isDeleted == (intent == .delete))
    }

    @Test("Delivered-only suppression never creates a warning, permission depends on remaining demand", arguments: [
        NotificationAuthorizationStatus.authorized, .denied, .notDetermined, .unknown
    ], [false, true])
    func deliveredSuppressionPermission(status: NotificationAuthorizationStatus, remainingDemand: Bool) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .reconciled(.init(desiredCount: remainingDemand ? 2 : 1,
            removedPendingCount: 0, removedDeliveredCount: 0,
            addedCount: remainingDemand && status.permitsScheduling ? 1 : 0,
            authorizationStatus: status, addFailures: [], planningFailures: [],
            deliveredDecisionSuppressedIdentifiers: ["soren.v2.renewalDecision.delivered.20261112.0"]))
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.delete())
        let expected: ItemDetailsViewModel.ReminderIssue?
        if !remainingDemand || status.permitsScheduling { expected = nil }
        else if status == .denied || status == .notDetermined { expected = .permission }
        else { expected = .reconciliation }
        #expect(vm.reminderIssue == expected && vm.isReminderAlertPresented == (expected != nil))
        #expect(vm.actionFailure == nil && repository.stored == nil && vm.hasPersistedDeletion)
        #expect(vm.isDeleted == (expected == nil) && vm.preventsDismissal == (expected != nil))
        #expect(repository.deleteCalls == 1 && repository.updateCalls == 0)
        #expect(notifications.sources == [.delete])
    }

    @Test("Existing add and planning failures still produce reconciliation warnings", arguments: [false, true])
    func existingReportFailures(planning: Bool) async throws {
        let source = try item()
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .reconciled(.init(desiredCount: planning ? 0 : 1, removedPendingCount: 0,
            removedDeliveredCount: 0, addedCount: 0, authorizationStatus: .authorized,
            addFailures: planning ? [] : [.addFailed(identifier: "another-item")],
            planningFailures: planning ? [.invalidDate(itemID: source.id)] : []))
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.perform(.pause))
        #expect(vm.reminderIssue == .reconciliation && vm.isReminderAlertPresented && vm.canRetryReminders)
        #expect(vm.actionFailure == nil && vm.item.status == .paused)
        #expect(repository.updateCalls == 1 && repository.deleteCalls == 0)
    }

    @Test("Notification-only retry preserves configured decision data and exposes retention facts")
    func decisionNotificationOnlyRetry() async throws {
        var source = try item()
        source.renewalDecisionDeadline = try CivilDate(year: 2026, month: 11, day: 12)
        source.renewalDecisionReminderEnabled = true
        let repository = DetailsActionRepository(source)
        let notifications = DetailsActionNotifications()
        notifications.outcome = .repositoryFetchFailed
        let vm = model(source, repository: repository, coordinator: notifications)
        #expect(try await vm.perform(.pause))
        let persisted = try #require(repository.stored)
        #expect(vm.canRetryReminders && repository.updateCalls == 1)
        notifications.outcome = .reconciled(NotificationReconciliationReport(desiredCount: 1, removedPendingCount: 0,
            removedDeliveredCount: 0, addedCount: 1, authorizationStatus: .authorized, addFailures: [], planningFailures: [],
            missingPendingIdentifiers: ["soren.v2.renewalDecision.missing.20261112.0"], pendingCountAfterReconciliation: 0))
        #expect(await vm.retryReminders())
        #expect(repository.stored == persisted && repository.updateCalls == 1 && repository.deleteCalls == 0)
        #expect(repository.stored?.renewalDecisionDeadline == source.renewalDecisionDeadline)
        #expect(repository.stored?.renewalDecisionReminderEnabled == true)
        guard case .reconciled(let report) = vm.lastNotificationOutcome else { Issue.record("Missing retry report"); return }
        #expect(report.hasSchedulingIssues && report.missingPendingIdentifiers.count == 1)
        #expect(notifications.sources == [.update, .other])
    }
}
