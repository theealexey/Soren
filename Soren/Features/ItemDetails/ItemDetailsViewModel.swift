import Foundation

// MARK: - Item Details View Model

/// Drives the Item Details screen: display, edit, status changes, and deletion.
@MainActor @Observable
final class ItemDetailsViewModel {

    // MARK: - Display State

    var item: RecurringItem {
        didSet { refreshNextScheduledCharge(); refreshNormalizedCosts() }
    }
    private(set) var normalizedMonthlyAmount: Decimal?
    private(set) var normalizedAnnualAmount: Decimal?
    private(set) var normalizationError: Error?

    private func refreshNormalizedCosts() {
        do {
            let annual = try item.annualEquivalent
            normalizedAnnualAmount = annual
            normalizedMonthlyAmount = annual / 12
            normalizationError = nil
        } catch {
            normalizedAnnualAmount = nil
            normalizedMonthlyAmount = nil
            normalizationError = error
        }
    }
    enum NextScheduledChargeState: Equatable {
        case scheduled(CivilDate)
        case notScheduled
        case unavailable
    }
    private(set) var nextScheduledChargeState: NextScheduledChargeState = .unavailable
    private(set) var nextScheduledChargeError: Error?
    private(set) var formattedNextCharge = String(localized: "itemDetails.nextScheduledCharge.unavailable")
    var isEditing = false
    var showDeleteConfirmation = false
    private(set) var isDeleted = false

    enum ActionIntent: Equatable, CaseIterable {
        case save, pause, resume, archive, delete

        var failureTitle: String {
            switch self {
            case .save: String(localized: "itemDetails.action.saveFailed")
            case .pause: String(localized: "itemDetails.action.pauseFailed")
            case .resume: String(localized: "itemDetails.action.resumeFailed")
            case .archive: String(localized: "itemDetails.action.archiveFailed")
            case .delete: String(localized: "itemDetails.action.deleteFailed")
            }
        }
    }

    struct ActionFailure {
        enum Kind: Equatable { case invalidInput, missingRecord, persistence }
        let intent: ActionIntent
        let kind: Kind
        let message: String
        let underlyingError: Error
        var canRetry: Bool { kind == .persistence }
    }

    enum ReminderIssue: Equatable { case reconciliation, permission }
    private(set) var isPerformingAction = false
    private(set) var actionFailure: ActionFailure?
    private(set) var reminderIssue: ReminderIssue?
    private(set) var isReminderAlertPresented = false
    private(set) var lastNotificationOutcome: NotificationRefreshOutcome?
    private(set) var hasPersistedDeletion = false
    private(set) var isEditSheetTransitionPending = false

    /// Shared by visible controls and execution, including retained failure retries.
    var pauseResumeIntent: ActionIntent? {
        guard item.archivedAt == nil, let today,
              (try? item.isExpired(on: today)) == false else { return nil }
        switch item.status {
        case .active, .dueSoon, .dueToday, .overdue, .trial, .failed:
            return .pause
        case .paused:
            return .resume
        case .archived, .cancelled:
            return nil
        }
    }

    var mutationsDisabled: Bool { isPerformingAction || hasPersistedDeletion || reminderIssue != nil }
    var preventsDismissal: Bool { isPerformingAction || (hasPersistedDeletion && !isDeleted) }
    var canRetryReminders: Bool { reminderIssue == .reconciliation && notificationCoordinator != nil }
    var canPresentDetailsAlert: Bool { !isEditing && !isEditSheetTransitionPending }
    var reminderMessage: String {
        let result = hasPersistedDeletion
            ? String(localized: "itemDetails.reminders.deleted")
            : String(localized: "itemDetails.reminders.saved")
        if reminderIssue == .permission {
            return result + "\n\n" + String(localized: "itemDetails.reminders.permission")
        }
        return result
    }

    func dismissActionFailure() { actionFailure = nil }

    func dismissReminderAlert() { isReminderAlertPresented = false }

    func acknowledgeReminderIssue() {
        guard !isPerformingAction else { return }
        reminderIssue = nil
        isReminderAlertPresented = false
        if hasPersistedDeletion { isDeleted = true }
    }

    func editSheetDidDismiss() { isEditSheetTransitionPending = false }

    // MARK: - Edit Form Fields

    var editTitle = ""
    var editAmountText = "" {
        didSet {
            if oldValue != editAmountText { scheduleCurrencyEstimate() }
        }
    }
    var editCurrencyCode = "RUB" {
        didSet {
            if oldValue != editCurrencyCode { scheduleCurrencyEstimate() }
        }
    }
    private(set) var reportingCurrencyCode: String
    private(set) var currencyEstimateState: CurrencyEstimateState = .hidden
    var editBillingCycle: BillingCycle = .monthly {
        didSet {
            if !isEditNextChargeDateManuallySet {
                recomputeEditNextChargeDay()
            }
            recomputeEditEndDateIfNeeded()
        }
    }
    var editCategory: ItemCategory = .other
    var editItemType: ItemType = .subscription
    var editStartDate: CivilDate? {
        didSet {
            guard !isEditNextChargeDateManuallySet else { return }
            recomputeEditNextChargeDay()
        }
    }
    var editNextChargeDate: CivilDate? {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    /// True once the user explicitly picks a next-charge date from the edit form,
    /// or once `startEditing()` seeds the form from a stored item (the stored value
    /// is treated as manually committed so cycle/startDate changes don't clobber it
    /// on first load). Reset via `resetEditNextChargeToAutomatic()` if we ever add
    /// that affordance.
    private(set) var isEditNextChargeDateManuallySet = false
    var editNote = ""
    var editUsageStatus: UsageStatus = .unknown

    // MARK: - Edit Lifecycle Fields

    var editAutoRenew: Bool = true {
        didSet { recomputeEditEndDateIfNeeded() }
    }
    var editEndDate: CivilDate?
    private(set) var dateInputError: Error?
    private(set) var isEditEndDateManuallySet = false

    var editChargeReminder: ChargeReminderOption = .threeDaysBefore
    var editTrialReminder: TrialReminderOption = .never

    // MARK: - Dependencies

    private let updateRecurringItem: UpdateRecurringItem
    private let notificationCoordinator: (any NotificationStateReconciling)?
    private let deleteRecurringItem: DeleteRecurringItem
    private let currencyEstimateService: CurrencyEstimateService
    private let preferences: UserPreferencesRepository
    private let now: () -> Date
    private let timeZone: () -> TimeZone
    private var estimateTask: Task<Void, Never>?
    private var currentEstimateRequest: CurrencyEstimateRequest?

    // MARK: - Init

    init<Provider: ExchangeRateProvider>(
        item: RecurringItem,
        repositories: RepositoryContainer,
        exchangeRateProvider: Provider,
        notificationCoordinator: (any NotificationStateReconciling)? = nil,
        convertMoney: ConvertMoneyUseCase = ConvertMoneyUseCase(),
        preferences: UserPreferencesRepository = UserPreferencesRepository(),
        now: @escaping () -> Date = { .now },
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.item = item
        self.notificationCoordinator = notificationCoordinator
        self.updateRecurringItem = UpdateRecurringItem(
            repository: repositories.recurringItems,
            notificationCoordinator: notificationCoordinator
        )
        self.deleteRecurringItem = DeleteRecurringItem(
            repository: repositories.recurringItems,
            notificationCoordinator: notificationCoordinator
        )
        self.currencyEstimateService = CurrencyEstimateService(
            exchangeRateProvider: exchangeRateProvider,
            convertMoney: convertMoney
        )
        self.preferences = preferences
        self.now = now
        self.timeZone = timeZone
        self.reportingCurrencyCode = preferences.load().defaultCurrencyCode
        refreshNextScheduledCharge()
        refreshNormalizedCosts()
    }

    init(
        item: RecurringItem,
        updateRecurringItem: UpdateRecurringItem,
        deleteRecurringItem: DeleteRecurringItem,
        currencyEstimateService: CurrencyEstimateService,
        notificationCoordinator: (any NotificationStateReconciling)? = nil,
        preferences: UserPreferencesRepository,
        now: @escaping () -> Date = { .now },
        timeZone: @escaping () -> TimeZone = { .current }
    ) {
        self.item = item
        self.notificationCoordinator = notificationCoordinator
        self.updateRecurringItem = updateRecurringItem
        self.deleteRecurringItem = deleteRecurringItem
        self.currencyEstimateService = currencyEstimateService
        self.preferences = preferences
        self.now = now
        self.timeZone = timeZone
        self.reportingCurrencyCode = preferences.load().defaultCurrencyCode
        refreshNextScheduledCharge()
        refreshNormalizedCosts()
    }

    // MARK: - Edit Next Charge Date

    /// Called by the next-charge-date binding in the edit form to record a user-chosen date.
    /// Once called, auto-fill stops updating editNextChargeDate for changes to cycle or startDate.
    func setEditNextChargeDateManually(_ date: CivilDate?) {
        editNextChargeDate = date
        isEditNextChargeDateManuallySet = true
    }

    // MARK: - Edit End Date

    func setEditEndDateManually(_ date: CivilDate?) {
        editEndDate = date
        isEditEndDateManuallySet = true
    }

    private func recomputeEditEndDateIfNeeded() {
        guard !editAutoRenew, !isEditEndDateManuallySet else { return }
        guard let editNextChargeDate else { return }
        do { editEndDate = try AddSubscriptionViewModel.nextDay(after: editNextChargeDate, cycle: editBillingCycle) }
        catch { dateInputError = error }
    }

    private func recomputeEditNextChargeDay() {
        guard let editStartDate else { return }
        do {
            let today = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
            editNextChargeDate = try AddSubscriptionViewModel.suggestNextChargeDay(
                from: editStartDate, cycle: editBillingCycle, today: today
            )
        } catch { dateInputError = error }
    }

    // MARK: - Edit Actions

    func startEditing() {
        guard !mutationsDisabled else { return }
        actionFailure = nil
        isEditSheetTransitionPending = true
        dateInputError = nil
        editTitle = item.title
        editAmountText = item.amount.description   // locale-independent decimal string
        editCurrencyCode = item.currencyCode
        editCategory = item.category
        editItemType = item.itemType
        editNote = item.note
        editUsageStatus = item.usageStatus
        // Lifecycle fields: set the manual-override flag before assigning cycle/date so
        // their didSet handlers don't auto-fill endDate/nextChargeDate for existing stored
        // values. Stored nextChargeDate is treated as manually committed — otherwise
        // assigning editStartDate / editBillingCycle below would auto-suggest a new
        // nextChargeDate and silently overwrite the user's persisted date on form open.
        isEditEndDateManuallySet = item.endDate != nil
        isEditNextChargeDateManuallySet = true
        editBillingCycle = item.billingCycle
        // Seed endDate: use stored value, or compute a sensible default for existing
        // auto-renew items (unused unless the user switches autoRenew off).
        do {
            editStartDate = try BillingCivilDay.civilDate(fromCanonicalDate: item.startDate)
            let next = try BillingCivilDay.civilDate(fromCanonicalDate: item.nextChargeDate)
            editNextChargeDate = next
            editEndDate = try item.endDate.map { try BillingCivilDay.civilDate(fromCanonicalDate: $0) }
                ?? AddSubscriptionViewModel.nextDay(after: next, cycle: item.billingCycle)
        } catch { dateInputError = error }
        editAutoRenew = item.autoRenew
        // Release the manual-override flag now that seed is complete. Subsequent
        // startDate / billingCycle changes made by the user in this session will
        // auto-recompute nextChargeDate — until the user explicitly picks one via
        // the date binding, at which point setEditNextChargeDateManually re-locks it.
        isEditNextChargeDateManuallySet = false
        editChargeReminder = item.chargeReminder
        editTrialReminder  = item.trialReminder
        isEditing = true
        refreshReportingCurrency()
    }

    func cancelEditing() {
        guard !isPerformingAction else { return }
        actionFailure = nil
        cancelCurrencyEstimate()
        isEditing = false
    }

    @discardableResult
    func saveChanges() async throws -> Bool { try await perform(.save) }

    @discardableResult
    func togglePause() async throws -> Bool {
        try await perform(item.status == .paused ? .resume : .pause)
    }

    @discardableResult
    func archive() async throws -> Bool { try await perform(.archive) }

    @discardableResult
    func delete() async throws -> Bool { try await perform(.delete) }

    /// MainActor owns the gate through persistence, reconciliation and publication.
    /// A rejected duplicate returns false, so callers cannot emit success feedback.
    @discardableResult
    func perform(_ intent: ActionIntent) async throws -> Bool {
        guard !mutationsDisabled, !isDeleted, !Task.isCancelled else { return false }
        if intent == .pause || intent == .resume {
            guard pauseResumeIntent == intent else { return false }
        }
        isPerformingAction = true
        actionFailure = nil
        defer { isPerformingAction = false }
        do {
            let outcome: NotificationRefreshOutcome?
            if intent == .delete {
                outcome = try await deleteRecurringItem.execute(id: item.id)
                hasPersistedDeletion = true
            } else {
                var updated = intent == .save ? try editedItem() : item
                switch intent {
                case .pause: updated.status = .paused
                case .resume: updated.status = .active
                case .archive:
                    updated.status = .archived
                    updated.archivedAt = now()
                case .save, .delete: break
                }
                let result = try await updateRecurringItem.execute(updated)
                item = result.item
                outcome = result.notificationOutcome
            }
            // Cancellation is not rollback: publish a completed persisted mutation.
            receiveNotificationOutcome(outcome)
            if intent == .save {
                cancelCurrencyEstimate()
                isEditing = false
            }
            if hasPersistedDeletion && reminderIssue == nil { isDeleted = true }
            return true
        } catch {
            actionFailure = failure(for: error, intent: intent)
            throw error
        }
    }

    @discardableResult
    func retryFailedAction() async throws -> Bool {
        guard let failure = actionFailure, failure.canRetry else { return false }
        return try await perform(failure.intent)
    }

    @discardableResult
    func retryReminders() async -> Bool {
        guard !isPerformingAction, canRetryReminders, let notificationCoordinator else { return false }
        isPerformingAction = true
        defer { isPerformingAction = false }
        isReminderAlertPresented = false
        let outcome = await notificationCoordinator.reconcileCurrentState(source: .other)
        receiveNotificationOutcome(outcome)
        if hasPersistedDeletion && reminderIssue == nil { isDeleted = true }
        return true
    }

    private func receiveNotificationOutcome(_ outcome: NotificationRefreshOutcome?) {
        lastNotificationOutcome = outcome
        switch outcome {
        case .reconciled(let report):
            if report.desiredCount > 0 && (report.authorizationStatus == .denied || report.authorizationStatus == .notDetermined) {
                reminderIssue = .permission
            } else if !report.addFailures.isEmpty || !report.planningFailures.isEmpty ||
                        (report.desiredCount > 0 && !report.authorizationStatus.permitsScheduling) {
                reminderIssue = .reconciliation
            } else {
                reminderIssue = nil
            }
        case .repositoryFetchFailed:
            reminderIssue = .reconciliation
        case .superseded, nil:
            // No confirmed failure or scheduling success; retain the actual outcome.
            // During retry keep an existing unresolved warning until acknowledged.
            break
        }
        isReminderAlertPresented = reminderIssue != nil
    }

    private func failure(for error: Error, intent: ActionIntent) -> ActionFailure {
        let kind: ActionFailure.Kind
        let message: String
        if let validation = error as? UpdateRecurringItem.ValidationError {
            kind = .invalidInput
            message = ValidationErrorFormatter.localizedMessage(for: validation)
        } else if let repository = error as? RepositoryError, case .notFound = repository {
            kind = .missingRecord
            message = String(localized: "itemDetails.action.missing")
        } else if error is BillingCycle.ValidationError || error is BillingCivilDayError ||
                    error is RecurringItemBillingDateValidationError || error is RecurringItemBillingDateAdapterError {
            kind = .invalidInput
            message = String(localized: "itemDetails.action.invalidInput")
        } else {
            kind = .persistence
            message = intent.failureTitle
        }
        return ActionFailure(intent: intent, kind: kind, message: message, underlyingError: error)
    }

    private func editedItem() throws -> RecurringItem {
        if let dateInputError { throw dateInputError }
        guard let editStartDate, let editNextChargeDate else { throw BillingCivilDayError.arithmeticFailed }
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")) else {
            throw UpdateRecurringItem.ValidationError.invalidAmount
        }

        var updated = item
        updated.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.amount = amount
        updated.currencyCode = editCurrencyCode
        updated.billingCycle = editBillingCycle
        updated.category = editCategory
        updated.itemType = editItemType
        updated.startDate = try BillingCivilDay.canonicalDate(for: editStartDate)
        updated.nextChargeDate = try BillingCivilDay.canonicalDate(for: editNextChargeDate)
        updated.autoRenew = editAutoRenew
        updated.endDate = try editAutoRenew ? nil : editEndDate.map { try BillingCivilDay.canonicalDate(for: $0) }
        updated.chargeReminder = editChargeReminder
        updated.trialReminder  = editTrialReminder
        updated.note = editNote
        updated.usageStatus = editUsageStatus

        return updated
    }

    // MARK: - Derived Currency Estimate

    func refreshReportingCurrency() {
        let latestCode = preferences.load().defaultCurrencyCode
        if latestCode != reportingCurrencyCode {
            reportingCurrencyCode = latestCode
            currentEstimateRequest = nil
        }
        scheduleCurrencyEstimate()
    }

    func cancelCurrencyEstimate() {
        estimateTask?.cancel()
        estimateTask = nil
        currentEstimateRequest = nil
        currencyEstimateState = .hidden
    }

    private func scheduleCurrencyEstimate() {
        guard isEditing else { return }
        guard
            let amount = parsedEditAmount,
            amount > 0,
            let request = try? CurrencyEstimateRequest(
                amount: amount,
                originalCurrencyCode: editCurrencyCode,
                targetCurrencyCode: reportingCurrencyCode
            ),
            request.requiresConversion
        else {
            cancelCurrencyEstimate()
            return
        }

        guard request != currentEstimateRequest else { return }

        estimateTask?.cancel()
        currentEstimateRequest = request
        currencyEstimateState = .loading

        let service = currencyEstimateService
        estimateTask = Task { [weak self] in
            let state: CurrencyEstimateState
            do {
                state = .available(try await service.estimate(request))
            } catch {
                state = .unavailable
            }

            guard !Task.isCancelled else { return }
            guard let self, self.currentEstimateRequest == request else { return }
            self.currencyEstimateState = state
            self.estimateTask = nil
        }
    }

    private var parsedEditAmount: Decimal? {
        Decimal(string: editAmountText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Computed

    var today: CivilDate? { try? BillingCivilDay.civilDate(containing: now(), in: timeZone()) }
    var isActiveTrial: Bool {
        guard let today else { return false }
        return (try? item.isActiveTrial(on: today)) ?? false
    }
    var renewalDisplay: RecurringItem.RenewalDisplay {
        guard let today else { return .renewing }
        return (try? item.renewalDisplay(relativeTo: today)) ?? .renewing
    }
    var daysUntilTrialEnd: Int? {
        guard let today else { return nil }
        return try? item.daysUntilTrialEnd(from: today)
    }

    var canSave: Bool {
        guard dateInputError == nil, let editNextChargeDate, editStartDate != nil else { return false }
        let trimmed = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 255 else { return false }
        guard let amount = Decimal(string: editAmountText.replacingOccurrences(of: ",", with: ".")),
              amount > 0, amount < 1_000_000_000 else { return false }
        if !editAutoRenew {
            guard let editEndDate else { return false }
            guard editEndDate >= editNextChargeDate else { return false }
        }
        return true
    }

    /// Refreshes at presentation and when the source item changes, rather than
    /// running schedule projection during SwiftUI body evaluation.
    func refreshNextScheduledCharge() {
        do {
            let today = try BillingCivilDay.civilDate(containing: now(), in: timeZone())
            if let day = try RecurringScheduleProjector().nextScheduledCharge(for: item, onOrAfter: today) {
                let formatted = try BillingDatePresentation.string(from: BillingCivilDay.canonicalDate(for: day))
                nextScheduledChargeState = .scheduled(day)
                formattedNextCharge = formatted
            } else {
                nextScheduledChargeState = .notScheduled
                formattedNextCharge = String(localized: "itemDetails.nextScheduledCharge.notScheduled")
            }
            nextScheduledChargeError = nil
        } catch {
            nextScheduledChargeError = error
            nextScheduledChargeState = .unavailable
            formattedNextCharge = String(localized: "itemDetails.nextScheduledCharge.unavailable")
        }
    }

    var formattedStartDate: String {
        (try? BillingDatePresentation.string(from: item.startDate, template: "dMMMMyyyy")) ?? ""
    }
}
