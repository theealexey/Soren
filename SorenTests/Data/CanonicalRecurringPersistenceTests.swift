import Foundation
import SwiftData
import Testing
@testable import Soren

@MainActor
struct CanonicalRecurringUseCaseTests {
    @Test(arguments: RecurringItemBillingDateValidationError.Field.allCases)
    func saveRejectsEachRawFieldBeforeRepository(field: RecurringItemBillingDateValidationError.Field) async throws {
        let repository = CanonicalWriteSpy()
        let item = try rawFieldItem(field)
        let error = await #expect(throws: RecurringItemBillingDateValidationError.self) {
            try await SaveRecurringItem(repository: repository).execute(item)
        }
        #expect(error?.field == field)
        #expect(repository.writes == 0)
    }

    @Test(arguments: RecurringItemBillingDateValidationError.Field.allCases)
    func updateRejectsEachRawFieldBeforeRepository(field: RecurringItemBillingDateValidationError.Field) async throws {
        let repository = CanonicalWriteSpy()
        let item = try rawFieldItem(field)
        let error = await #expect(throws: RecurringItemBillingDateValidationError.self) {
            try await UpdateRecurringItem(repository: repository).execute(item)
        }
        #expect(error?.field == field)
        #expect(repository.writes == 0)
    }

    @Test(arguments: [false, true])
    func validOptionalTupleAccepted(optionalDates: Bool) async throws {
        let repository = CanonicalWriteSpy()
        var item = try canonicalTestItem()
        if optionalDates {
            item.trialEndDate = try canonicalTestDay(16)
            item.autoRenew = false
            item.endDate = try canonicalTestDay(20)
        }
        _ = try await SaveRecurringItem(repository: repository).execute(item)
        _ = try await UpdateRecurringItem(repository: repository).execute(item)
        #expect(repository.writes == 2)
    }

    private func rawFieldItem(_ field: RecurringItemBillingDateValidationError.Field) throws -> RecurringItem {
        var item = try canonicalTestItem()
        switch field {
        case .startDate: item.startDate = item.startDate.addingTimeInterval(1)
        case .nextChargeDate: item.nextChargeDate = item.nextChargeDate.addingTimeInterval(1)
        case .trialEndDate: item.trialEndDate = try canonicalTestDay(16).addingTimeInterval(1)
        case .endDate: item.endDate = try canonicalTestDay(20).addingTimeInterval(1)
        }
        return item
    }
}

@MainActor
struct CanonicalRecurringMapperTests {
    @Test func canonicalReadKeepsAuditInstantsAndOptionalNils() throws {
        var item = try canonicalTestItem()
        item.updatedAt = Date(timeIntervalSinceReferenceDate: 1.25)
        let row = try RecurringItemMapper.toSD(item)
        row.legacyBillingDateInterpretationTimeZoneIdentifier = "Not/AZone"
        let output = try RecurringItemMapper.toDomain(row)
        #expect(output == item)
        #expect(row.billingDateEncodingVersion == 1)
        #expect(output.trialEndDate == nil)
        #expect(output.endDate == nil)
    }

    @Test func legacyReadInterpretsOnlyStoredZone() throws {
        let row = try legacyTestRow()
        let raw = row.nextChargeDate
        let output = try RecurringItemMapper.toDomain(row)
        #expect(try BillingCivilDay.civilDate(fromCanonicalDate: output.nextChargeDate).day == 15)
        #expect(row.nextChargeDate == raw)
        #expect(row.billingDateEncodingVersion == nil)
    }

    @Test(arguments: [0, 1, 2, 3])
    func metadataFailuresRemainTyped(state: Int) throws {
        let row = try legacyTestRow()
        switch state {
        case 0: row.legacyBillingDateInterpretationTimeZoneIdentifier = nil
        case 1: row.legacyBillingDateInterpretationTimeZoneIdentifier = "Not/AZone"
        case 2: row.billingDateEncodingVersion = 99
        default: row.billingDateEncodingVersion = 1
        }
        do {
            _ = try RecurringItemMapper.toDomain(row)
            Issue.record("Invalid persisted tuple was accepted")
        } catch let error as RecurringItemBillingDateAdapterError {
            switch (state, error) {
            case (0, .missingLegacyProvenance(let id)): #expect(id == row.id)
            case (1, .invalidLegacyTimeZoneIdentifier(let id, let zone)):
                #expect(id == row.id && zone == "Not/AZone")
            case (2, .unsupportedEncodingVersion(let id, let version)):
                #expect(id == row.id && version == 99)
            case (3, .invalidCanonicalBillingDate(let id, let field, _)):
                #expect(id == row.id && field == .startDate)
            default: Issue.record("Wrong metadata failure: \(error)")
            }
        }
    }

    @Test func failedPreparationDoesNotMutateAnyField() throws {
        let row = try legacyTestRow()
        let original = try RecurringItemMapper.toDomain(row)
        let raw = [row.startDate, row.nextChargeDate, row.trialEndDate, row.endDate]
        var replacement = original
        replacement.title = "Must not mutate"
        replacement.endDate = try canonicalTestDay(20).addingTimeInterval(1)
        #expect(throws: RecurringItemBillingDateAdapterError.self) {
            try RecurringItemMapper.update(row, from: replacement)
        }
        #expect(row.title == original.title)
        #expect([row.startDate, row.nextChargeDate, row.trialEndDate, row.endDate] == raw)
        #expect(row.billingDateEncodingVersion == nil)
        #expect(row.legacyBillingDateInterpretationTimeZoneIdentifier == "Europe/Stockholm")
    }
}

@MainActor
struct CanonicalRecurringRepositoryTests {
    @Test("Failed update/delete commits roll back and can be retried", arguments: [false, true])
    func failedActionCommitRollsBack(delete: Bool) throws {
        let original = try canonicalTestItem()
        let container = try seededContainer([RecurringItemMapper.toSD(original)])
        var fails = true
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            if fails { throw CanonicalTestSaveFailure.failed }
            try context.save()
        }
        var changed = original
        changed.title = "Retained edit"
        #expect(throws: CanonicalTestSaveFailure.failed) {
            if delete { try repository.delete(id: original.id) }
            else { try repository.update(changed) }
        }
        #expect(try repository.fetch(id: original.id) == original)
        let fresh = SwiftDataRecurringItemRepository(container: container)
        #expect(try fresh.fetch(id: original.id) == original)
        fails = false
        if delete { try repository.delete(id: original.id) }
        else { try repository.update(changed) }
        let after = try SwiftDataRecurringItemRepository(container: container).fetch(id: original.id)
        #expect(after == (delete ? nil : changed))
    }

    @Test func mixedReadsUseCanonicalOrdering() throws {
        let legacy = try legacyTestRow()
        let canonical = try RecurringItemMapper.toSD(canonicalTestItem())
        legacy.id = try #require(UUID(uuidString: "22222222-2222-4222-8222-222222222222"))
        canonical.id = try #require(UUID(uuidString: "11111111-1111-4111-8111-111111111111"))
        legacy.title = "Zulu"
        canonical.title = "Alpha"
        // Both decode to August 15, despite different raw timestamps.
        let container = try seededContainer([legacy, canonical])
        let repository = SwiftDataRecurringItemRepository(container: container)
        let expected = [legacy.id, canonical.id].sorted { $0.uuidString < $1.uuidString }
        #expect(try repository.fetchAll().map(\.id) == expected)
        #expect(try repository.fetchActive().map(\.id) == expected)
        #expect(try repository.fetchByCategory(.other).map(\.title) == ["Alpha", "Zulu"])
        #expect(try repository.fetch(id: legacy.id)?.nextChargeDate == canonicalTestDay())
    }

    @Test func upcomingIncludesLegacyAtLowerBoundaryAndInclusiveUpperBoundary() throws {
        let legacy = try legacyTestRow()
        var upper = try canonicalTestItem()
        upper.nextChargeDate = try canonicalTestDay(22)
        var beyond = try canonicalTestItem()
        beyond.nextChargeDate = try canonicalTestDay(23)
        let container = try seededContainer([legacy, RecurringItemMapper.toSD(upper), RecurringItemMapper.toSD(beyond)])
        let repository = SwiftDataRecurringItemRepository(container: container)
        #expect(try repository.fetchUpcoming(within: 7, from: canonicalTestDay()).map(\.id) == [legacy.id, upper.id])
        #expect(try repository.fetchUpcoming(within: 0, from: canonicalTestDay()).isEmpty)
        #expect(throws: BillingCivilDayError.self) {
            try repository.fetchUpcoming(within: 7, from: canonicalTestDay().addingTimeInterval(1))
        }
    }

    @Test(arguments: [0, 1, 2, 3, 4])
    func everyReadPropagatesInvalidRow(api: Int) throws {
        let bad = try legacyTestRow()
        bad.legacyBillingDateInterpretationTimeZoneIdentifier = nil
        let container = try seededContainer([bad])
        let repository = SwiftDataRecurringItemRepository(container: container)
        do {
            switch api {
            case 0: _ = try repository.fetchAll()
            case 1: _ = try repository.fetchActive()
            case 2: _ = try repository.fetchUpcoming(within: 7, from: canonicalTestDay())
            case 3: _ = try repository.fetchByCategory(.other)
            default: _ = try repository.fetch(id: bad.id)
            }
            Issue.record("Invalid row was silently omitted")
        } catch RecurringItemBillingDateAdapterError.missingLegacyProvenance(let id) {
            #expect(id == bad.id)
        }
    }

    @Test func freshCreateAndCanonicalUpdatePersistFullVersionOneTuple() throws {
        let container = try seededContainer([])
        let repository = SwiftDataRecurringItemRepository(container: container)
        var item = try canonicalTestItem()
        item.trialEndDate = try canonicalTestDay(16)
        item.endDate = try canonicalTestDay(20)
        item.autoRenew = false
        try repository.save(item)
        var stored = try inspectionRow(container, id: item.id)
        #expect(stored.billingDateEncodingVersion == 1)
        #expect(stored.legacyBillingDateInterpretationTimeZoneIdentifier == nil)
        #expect(try RecurringItemMapper.toDomain(stored) == item)
        item.startDate = try canonicalTestDay(2)
        item.nextChargeDate = try canonicalTestDay(17)
        item.trialEndDate = nil
        item.endDate = try canonicalTestDay(21)
        try repository.update(item)
        stored = try inspectionRow(container, id: item.id)
        #expect(try RecurringItemMapper.toDomain(stored) == item)
        #expect(stored.billingDateEncodingVersion == 1)
    }

    @Test func invalidCreateDoesNotInsertOrSave() throws {
        let container = try seededContainer([])
        var saves = 0
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            saves += 1
            try context.save()
        }
        var item = try canonicalTestItem()
        item.trialEndDate = try canonicalTestDay(16).addingTimeInterval(1)
        #expect(throws: RecurringItemBillingDateAdapterError.self) { try repository.save(item) }
        #expect(saves == 0)
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test func invalidCanonicalUpdateLeavesPersistedTupleUnchanged() throws {
        let original = try canonicalTestItem()
        let container = try seededContainer([RecurringItemMapper.toSD(original)])
        var saves = 0
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            saves += 1
            try context.save()
        }
        var replacement = original
        replacement.title = "Must not change"
        replacement.endDate = try canonicalTestDay(20).addingTimeInterval(1)
        #expect(throws: RecurringItemBillingDateAdapterError.self) { try repository.update(replacement) }
        #expect(saves == 0)
        #expect(try repository.fetch(id: original.id) == original)
        #expect(try inspectionRow(container, id: original.id).billingDateEncodingVersion == 1)
    }

    @Test(arguments: [ItemStatus.active, .paused, .archived])
    func nonDateLegacyUpdatesCanonicalizeAllFields(status: ItemStatus) throws {
        let legacy = try legacyTestRow()
        legacy.trialEndDate = legacy.nextChargeDate
        legacy.endDate = try canonicalTestDay(20).addingTimeInterval(-7_200)
        let container = try seededContainer([legacy])
        let repository = SwiftDataRecurringItemRepository(container: container)
        let fetched = try repository.fetch(id: legacy.id)
        var replacement = try #require(fetched)
        replacement.title = "Non-date edit"
        replacement.status = status
        try repository.update(replacement)
        let stored = try inspectionRow(container, id: legacy.id)
        #expect(stored.billingDateEncodingVersion == 1)
        #expect(stored.legacyBillingDateInterpretationTimeZoneIdentifier == "Europe/Stockholm")
        #expect(try RecurringItemMapper.toDomain(stored) == replacement)
        for date in [stored.startDate, stored.nextChargeDate, stored.trialEndDate, stored.endDate].compactMap({ $0 }) {
            #expect(throws: Never.self) { try BillingCivilDay.civilDate(fromCanonicalDate: date) }
        }
        // A subsequent resume/full update retains canonical metadata and provenance.
        replacement.status = .active
        try repository.update(replacement)
        #expect(try inspectionRow(container, id: legacy.id).billingDateEncodingVersion == 1)
    }

    @Test(arguments: [false, true])
    func unreadableLegacyUpdateFailsBeforeMutation(unknownVersion: Bool) throws {
        let legacy = try legacyTestRow()
        legacy.legacyBillingDateInterpretationTimeZoneIdentifier = nil
        if unknownVersion { legacy.billingDateEncodingVersion = 99 }
        let container = try seededContainer([legacy])
        let repository = SwiftDataRecurringItemRepository(container: container)
        var replacement = try canonicalTestItem()
        replacement = RecurringItem(id: legacy.id, title: "Changed", amount: replacement.amount,
                                   startDate: replacement.startDate, nextChargeDate: replacement.nextChargeDate)
        #expect(throws: RecurringItemBillingDateAdapterError.self) { try repository.update(replacement) }
        let stored = try inspectionRow(container, id: legacy.id)
        #expect(stored.title == legacy.title)
        #expect(stored.billingDateEncodingVersion == (unknownVersion ? 99 : nil))
        #expect(stored.nextChargeDate == legacy.nextChargeDate)
    }

    @Test func saveAllPreparesEntireBatchAndSavesOnce() throws {
        let container = try seededContainer([])
        var saves = 0
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            saves += 1
            try context.save()
        }
        let first = try canonicalTestItem()
        var bad = try canonicalTestItem()
        bad.endDate = try canonicalTestDay(20).addingTimeInterval(1)
        #expect(throws: RecurringItemBillingDateAdapterError.self) { try repository.saveAll([first, bad]) }
        #expect(saves == 0)
        #expect(try repository.fetchAll().isEmpty)
        try repository.saveAll([first, canonicalTestItem()])
        #expect(saves == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<SDRecurringItem>()).allSatisfy {
            $0.billingDateEncodingVersion == 1 && $0.legacyBillingDateInterpretationTimeZoneIdentifier == nil
        })
    }

    @Test(arguments: [false, true])
    func failedCreateOrBatchRollsBackAndRetries(batch: Bool) throws {
        let container = try seededContainer([])
        var fail = true
        var attempted: ModelContext?
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            attempted = context
            if fail { throw CanonicalTestSaveFailure.failed }
            try context.save()
        }
        let items = try [canonicalTestItem(), canonicalTestItem()]
        #expect(throws: CanonicalTestSaveFailure.failed) {
            if batch { try repository.saveAll(items) } else { try repository.save(items[0]) }
        }
        #expect(try #require(attempted).hasChanges == false)
        #expect(try repository.fetchAll().isEmpty)
        fail = false
        if batch { try repository.saveAll(items) } else { try repository.save(items[0]) }
        #expect(try repository.fetchAll().count == (batch ? 2 : 1))
    }

    @Test func rollbackDoesNotTouchUnrelatedPendingPaymentContext() throws {
        let container = try seededContainer([])
        let main = container.mainContext
        main.autosaveEnabled = false
        // A pending unrelated payment-method change must neither save nor roll back.
        let method = SDPaymentMethod(id: UUID(), title: "Pending", typeRaw: "bankCard",
                                     maskedIdentifier: "1234", isDefault: false)
        main.insert(method)
        var fail = true
        let repository = SwiftDataRecurringItemRepository(container: container) { context in
            #expect(context !== main)
            #expect(context.autosaveEnabled == false)
            if fail { throw CanonicalTestSaveFailure.failed }
            try context.save()
        }
        let item = try canonicalTestItem()
        #expect(throws: CanonicalTestSaveFailure.failed) { try repository.save(item) }
        #expect(main.hasChanges)
        #expect(method.title == "Pending")
        fail = false
        try repository.save(item)
        #expect(main.hasChanges)
        #expect(try ModelContext(container).fetch(FetchDescriptor<SDPaymentMethod>()).isEmpty)
        main.rollback()
    }

    @Test func copiedLegacyStoreUpdateFailureReopenAndRetry() throws {
        let source = try #require(Bundle(for: CanonicalFixtureMarker.self).url(forResource: "CivilDateLegacyV1", withExtension: "fixture"))
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: temporary)
        defer {
            do { try FileManager.default.removeItem(at: temporary) }
            catch { Issue.record("Temporary copy cleanup failed: \(error)") }
        }
        let url = temporary.appendingPathComponent("default.store")
        try prepareDiskProvenance(url)
        let initial = try diskRead(url)
        try failedDiskUpdate(url)
        #expect(try diskRead(url) == initial)
        try successfulDiskUpdate(url)
        let after = try diskRead(url)
        #expect(after.allSatisfy { $0.version == 1 })
        #expect(after.allSatisfy { $0.provenance == "Europe/Stockholm" })
    }

    private func prepareDiskProvenance(_ url: URL) throws {
        let container = try diskContainer(url)
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        _ = try LegacyBillingDateProvenanceBootstrap().execute(container: container, interpretationTimeZone: zone)
    }

    private func failedDiskUpdate(_ url: URL) throws {
        let container = try diskContainer(url)
        let repository = SwiftDataRecurringItemRepository(container: container) { _ in throw CanonicalTestSaveFailure.failed }
        let fetched = try repository.fetchAll().first
        var replacement = try #require(fetched)
        let before = replacement
        replacement.title = "Must rollback"
        #expect(throws: CanonicalTestSaveFailure.failed) { try repository.update(replacement) }
        #expect(try repository.fetch(id: replacement.id) == before)
        #expect(try inspectionRow(container, id: replacement.id).billingDateEncodingVersion == nil)
    }

    private func successfulDiskUpdate(_ url: URL) throws {
        let container = try diskContainer(url)
        let repository = SwiftDataRecurringItemRepository(container: container)
        for item in try repository.fetchAll() { try repository.update(item) }
    }

    private func diskRead(_ url: URL) throws -> [CanonicalDiskSnapshot] {
        let container = try diskContainer(url)
        return try ModelContext(container).fetch(FetchDescriptor<SDRecurringItem>()).map {
            CanonicalDiskSnapshot(id: $0.id, title: $0.title, version: $0.billingDateEncodingVersion,
                                  provenance: $0.legacyBillingDateInterpretationTimeZoneIdentifier,
                                  dates: [$0.startDate, $0.nextChargeDate, $0.trialEndDate, $0.endDate])
        }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private func diskContainer(_ url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(schema: SorenModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: SorenModelContainer.schema, configurations: config)
    }
}

private struct CanonicalDiskSnapshot: Equatable {
    let id: UUID
    let title: String
    let version: Int?
    let provenance: String?
    let dates: [Date?]
}

private enum CanonicalTestSaveFailure: Error { case failed }
private final class CanonicalFixtureMarker: NSObject { }

@MainActor
private func legacyTestRow() throws -> SDRecurringItem {
    let row = try RecurringItemMapper.toSD(canonicalTestItem())
    row.billingDateEncodingVersion = nil
    row.legacyBillingDateInterpretationTimeZoneIdentifier = "Europe/Stockholm"
    row.startDate = row.startDate.addingTimeInterval(-7_200)
    row.nextChargeDate = row.nextChargeDate.addingTimeInterval(-7_200)
    return row
}

@MainActor
private func seededContainer(_ rows: [SDRecurringItem]) throws -> ModelContainer {
    let container = try SorenModelContainer.inMemory()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    for row in rows { context.insert(row) }
    try context.save()
    return container
}

@MainActor
private func inspectionRow(_ container: ModelContainer, id: UUID) throws -> SDRecurringItem {
    let context = ModelContext(container)
    let rows = try context.fetch(FetchDescriptor<SDRecurringItem>())
    return try #require(rows.first { $0.id == id })
}

@MainActor
private final class CanonicalWriteSpy: RecurringItemRepository {
    var writes = 0
    func fetchAll() throws -> [RecurringItem] { [] }
    func fetchActive() throws -> [RecurringItem] { [] }
    func fetchUpcoming(within days: Int, from date: Date) throws -> [RecurringItem] { [] }
    func fetchByCategory(_ category: ItemCategory) throws -> [RecurringItem] { [] }
    func fetch(id: UUID) throws -> RecurringItem? { nil }
    func save(_ item: RecurringItem) throws { writes += 1 }
    func update(_ item: RecurringItem) throws { writes += 1 }
    func delete(id: UUID) throws { }
    func saveAll(_ items: [RecurringItem]) throws { writes += 1 }
    func deleteAll() throws { }
}

@MainActor
struct RenewalDecisionPersistenceTests {
    private func decision() throws -> CivilDate { try CivilDate(year: 2026, month: 3, day: 29) }

    @Test("Both Use Cases reject orphaned reminders before injected repository writes", arguments: [false, true])
    func rejectsBeforeWrite(update: Bool) async throws {
        let spy = CanonicalWriteSpy()
        var item = try canonicalTestItem()
        item.renewalDecisionReminderEnabled = true
        await #expect(throws: RecurringItem.RenewalDecisionValidationError.reminderRequiresDeadline) {
            if update { _ = try await UpdateRecurringItem(repository: spy).execute(item) }
            else { _ = try await SaveRecurringItem(repository: spy).execute(item) }
        }
        #expect(spy.writes == 0)
    }

    @Test("Nullable storage defaults and valid opt-in values round-trip", arguments: [0, 1, 2])
    func mapperRoundTrip(mode: Int) throws {
        var item = try canonicalTestItem()
        if mode > 0 { item.renewalDecisionDeadline = try decision() }
        item.renewalDecisionReminderEnabled = mode == 2
        item.status = .archived; item.archivedAt = Date(timeIntervalSince1970: 100.25)
        let row = try RecurringItemMapper.toSD(item)
        #expect(try RecurringItemMapper.toDomain(row) == item)
        if mode == 0 {
            row.renewalDecisionReminderEnabled = nil
            #expect(try RecurringItemMapper.toDomain(row) == item)
        }
        var changed = item; changed.note = "Ordinary update"
        try RecurringItemMapper.update(row, from: changed)
        #expect(try RecurringItemMapper.toDomain(row) == changed)
        changed.renewalDecisionDeadline = nil; changed.renewalDecisionReminderEnabled = false
        try RecurringItemMapper.update(row, from: changed)
        #expect(row.renewalDecisionDeadline == nil && row.renewalDecisionReminderEnabled == false)
        #expect(try RecurringItemMapper.toDomain(row) == changed)
    }

    @Test("Malformed persisted date and orphaned stored reminder throw without coercion", arguments: [false, true])
    func malformedStoredValue(orphan: Bool) throws {
        let row = try RecurringItemMapper.toSD(canonicalTestItem())
        if orphan {
            row.renewalDecisionReminderEnabled = true
            #expect(throws: RecurringItem.RenewalDecisionValidationError.reminderRequiresDeadline) { try RecurringItemMapper.toDomain(row) }
        } else {
            row.renewalDecisionDeadline = try CivilDateStorageCodec().encode(decision()).addingTimeInterval(1)
            #expect(throws: CivilDateStorageCodecError.self) { try RecurringItemMapper.toDomain(row) }
        }
    }

    @Test("Preparation failures cannot partially mutate existing managed fields")
    func preparationIsAtomic() throws {
        var item = try canonicalTestItem(); item.renewalDecisionDeadline = try decision()
        let row = try RecurringItemMapper.toSD(item)
        let oldDeadline = row.renewalDecisionDeadline
        var bad = item; bad.title = "Must not publish"; bad.renewalDecisionDeadline = nil; bad.renewalDecisionReminderEnabled = true
        #expect(throws: RecurringItem.RenewalDecisionValidationError.self) { try RecurringItemMapper.update(row, from: bad) }
        #expect(try RecurringItemMapper.toDomain(row) == item)
        bad = item; bad.title = "Must not publish"; bad.startDate = bad.startDate.addingTimeInterval(1)
        #expect(throws: RecurringItemBillingDateAdapterError.self) { try RecurringItemMapper.update(row, from: bad) }
        #expect(row.renewalDecisionDeadline == oldDeadline && row.title == item.title)
        row.renewalDecisionDeadline = oldDeadline?.addingTimeInterval(1)
        #expect(throws: CivilDateStorageCodecError.self) { try RecurringItemMapper.update(row, from: item) }
        #expect(row.renewalDecisionDeadline == oldDeadline?.addingTimeInterval(1))
    }

    @Test("New civil date ignores legacy interpretation policy, including DST", arguments: ["America/Los_Angeles", "Pacific/Kiritimati", "Europe/Stockholm"])
    func civilStorageIndependence(zoneID: String) throws {
        let row = try legacyTestRow()
        let raw = [row.startDate, row.nextChargeDate, row.trialEndDate, row.endDate]
        row.legacyBillingDateInterpretationTimeZoneIdentifier = zoneID
        row.renewalDecisionDeadline = try CivilDateStorageCodec().encode(decision())
        row.renewalDecisionReminderEnabled = true
        let value = try RecurringItemMapper.toDomain(row)
        #expect(value.renewalDecisionDeadline == (try decision()))
        #expect(value.renewalDecisionReminderEnabled)
        #expect(row.billingDateEncodingVersion == nil && row.legacyBillingDateInterpretationTimeZoneIdentifier == zoneID)
        #expect([row.startDate, row.nextChargeDate, row.trialEndDate, row.endDate] == raw)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = try #require(TimeZone(identifier: zoneID))
        let carrier = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12)))
        let civil = try BillingCivilDay.civilDate(containing: carrier, in: cal.timeZone)
        #expect(civil == value.renewalDecisionDeadline)
        if zoneID == "Europe/Stockholm" {
            let before = try #require(cal.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 12)))
            #expect(cal.timeZone.secondsFromGMT(for: carrier) - cal.timeZone.secondsFromGMT(for: before) == 3600)
        }
    }

    @Test("Save/update commit failure rolls back Renewal Control", arguments: [false, true])
    func rollback(update: Bool) throws {
        let item = try canonicalTestItem()
        let container = try seededContainer(update ? [RecurringItemMapper.toSD(item)] : [])
        let repository = SwiftDataRecurringItemRepository(container: container) { _ in throw CanonicalTestSaveFailure.failed }
        var changed = item; changed.renewalDecisionDeadline = try decision(); changed.renewalDecisionReminderEnabled = true
        #expect(throws: CanonicalTestSaveFailure.failed) {
            if update { try repository.update(changed) } else { try repository.save(changed) }
        }
        let fresh = SwiftDataRecurringItemRepository(container: container)
        #expect(try fresh.fetch(id: item.id) == (update ? item : nil))
    }

    @Test("Renewal Control does not participate in recurrence or monetary forecast")
    func scheduleUnchanged() throws {
        let item = try canonicalTestItem()
        var changed = item; changed.renewalDecisionDeadline = try decision(); changed.renewalDecisionReminderEnabled = true
        let a = SwiftDataRecurringItemRepository(container: try seededContainer([RecurringItemMapper.toSD(item)]))
        let b = SwiftDataRecurringItemRepository(container: try seededContainer([RecurringItemMapper.toSD(changed)]))
        let today = try CivilDate(year: 2026, month: 8, day: 15)
        #expect(try GetAnalyticsForecast(repository: a).execute(today: today) == GetAnalyticsForecast(repository: b).execute(today: today))
        let lower = try canonicalTestDay(1), upper = try BillingCivilDay.canonicalDate(for: CivilDate(year: 2027, month: 8, day: 1))
        #expect(try RecurringScheduleProjector().project(item, in: lower..<upper, asOf: lower, calendar: BillingCivilDay.calendar) == RecurringScheduleProjector().project(changed, in: lower..<upper, asOf: lower, calendar: BillingCivilDay.calendar))
    }

    @Test("Disk reopen preserves new values, old fields and nonempty relationships")
    func diskRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { do { try FileManager.default.removeItem(at: directory) } catch { Issue.record("Temporary cleanup failed: \(error)") } }
        let url = directory.appendingPathComponent("default.store")
        var item = try canonicalTestItem(); item.renewalDecisionDeadline = try decision(); item.renewalDecisionReminderEnabled = true
        item.status = .archived; item.archivedAt = Date(timeIntervalSince1970: 12345.25)
        try autoreleasepool {
            let container = try disk(url); let context = ModelContext(container); context.autosaveEnabled = false
            let row = try RecurringItemMapper.toSD(item); context.insert(row)
            let payment = SDPaymentRecord(id: UUID(), itemID: item.id, amountValue: 100, currencyCode: "RUB", paymentDate: item.startDate, statusRaw: "pending", paymentMethodID: nil, note: "Persistence fixture")
            context.insert(payment); payment.item = row
            let trigger = String(decoding: try JSONEncoder().encode(ReminderRule.Trigger.daysBefore(3)), as: UTF8.self)
            let rule = SDReminderRule(id: UUID(), recurringItemID: item.id, triggerRaw: trigger, isEnabled: true)
            context.insert(rule); rule.item = row
            try context.save()
        }
        try inspectDisk(url, expected: item)
        var cleared = item; cleared.renewalDecisionDeadline = nil; cleared.renewalDecisionReminderEnabled = false
        try autoreleasepool { try SwiftDataRecurringItemRepository(container: disk(url)).update(cleared) }
        try inspectDisk(url, expected: cleared)
    }

    private func disk(_ url: URL) throws -> ModelContainer {
        let config = ModelConfiguration(schema: SorenModelContainer.schema, url: url, allowsSave: true, cloudKitDatabase: .none)
        return try ModelContainer(for: SorenModelContainer.schema, configurations: config)
    }
    private func inspectDisk(_ url: URL, expected: RecurringItem) throws {
        try autoreleasepool {
            let container = try disk(url)
            #expect(try SwiftDataRecurringItemRepository(container: container).fetchAll() == [expected])
            let context = ModelContext(container)
            let row = try #require(context.fetch(FetchDescriptor<SDRecurringItem>()).first)
            #expect(row.payments.count == 1 && row.reminders.count == 1)
            #expect(row.payments.first?.item?.id == expected.id && row.reminders.first?.item?.id == expected.id)
            #expect(row.payments.first?.amountValue == 100 && row.reminders.first?.isEnabled == true)
        }
    }
}

extension RenewalDecisionPersistenceTests {
    @Test("Invalid stored Renewal Control blocks validation, not destructive recovery", arguments: [false, true])
    func invalidStoredRowBlocksSafely(orphan: Bool) throws {
        let row = try RecurringItemMapper.toSD(canonicalTestItem())
        if orphan { row.renewalDecisionReminderEnabled = true }
        else { row.renewalDecisionDeadline = row.startDate.addingTimeInterval(1) }
        let container = try seededContainer([row])
        let state = AppState(openStore: { container }, interpretationTimeZone: .gmt)
        #expect(state.preparationState == .civilDateBlocked)
        #expect(state.appContainer == nil && state.preparationError != nil)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SDRecurringItem>()) == 1)
    }
}

extension RenewalDecisionPersistenceTests {
    @Test("Use Cases preserve independent decision days before and after the charge", arguments: [2020, 2027])
    func validUseCaseDates(year: Int) async throws {
        let spy = CanonicalWriteSpy()
        var item = try canonicalTestItem()
        item.trialEndDate = item.nextChargeDate
        item.renewalDecisionDeadline = try CivilDate(year: year, month: 3, day: 29)
        item.renewalDecisionReminderEnabled = true
        let saved = try await SaveRecurringItem(repository: spy).execute(item).item
        let updated = try await UpdateRecurringItem(repository: spy).execute(saved).item
        #expect(spy.writes == 2)
        #expect(updated.renewalDecisionDeadline == item.renewalDecisionDeadline && updated.renewalDecisionReminderEnabled)
        #expect(updated.nextChargeDate == item.nextChargeDate && updated.trialEndDate == item.trialEndDate)
    }
    @Test("Legacy metadata does not manufacture Renewal Control defaults")
    func legacyDefaults() throws {
        let row = try legacyTestRow()
        row.renewalDecisionReminderEnabled = nil
        let value = try RecurringItemMapper.toDomain(row)
        #expect(value.renewalDecisionDeadline == nil && !value.renewalDecisionReminderEnabled)
        #expect(row.billingDateEncodingVersion == nil && row.legacyBillingDateInterpretationTimeZoneIdentifier == "Europe/Stockholm")
    }
}
