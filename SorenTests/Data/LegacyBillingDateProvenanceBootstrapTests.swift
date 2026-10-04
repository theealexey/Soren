import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import Soren

@Suite("Legacy billing-date provenance bootstrap")
@MainActor
struct LegacyBillingDateProvenanceBootstrapTests {
    @Test("All lifecycle rows receive only the explicitly supplied interpretation policy")
    func allLifecycles() throws {
        let statuses = ["active", "paused", "cancelled", "archived", "trial", "overdue", "failed", "unknown"]
        let container = try makeContainer(rows: statuses.map { makeRow(status: $0) })
        let before = try snapshots(container)
        let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))

        #expect(try LegacyBillingDateProvenanceBootstrap().execute(
            container: container, interpretationTimeZone: zone
        ) == statuses.count)

        #expect(try snapshots(container) == before)
        let after = try metadata(container)
        #expect(after.count == statuses.count)
        #expect(after.values.allSatisfy { $0.version == nil && $0.provenance == zone.identifier })
    }

    @Test("Existing provenance and every nonnil version remain untouched")
    func preserveMetadata() throws {
        let existing = makeRow()
        existing.legacyBillingDateInterpretationTimeZoneIdentifier = "Not/AZone"
        let versioned = makeRow()
        versioned.billingDateEncodingVersion = 1
        let versionedWithProvenance = makeRow()
        versionedWithProvenance.billingDateEncodingVersion = 1
        versionedWithProvenance.legacyBillingDateInterpretationTimeZoneIdentifier = "US/Eastern"
        let unknown = makeRow()
        unknown.billingDateEncodingVersion = 99
        unknown.legacyBillingDateInterpretationTimeZoneIdentifier = "America/New_York"
        let unknownWithoutProvenance = makeRow()
        unknownWithoutProvenance.billingDateEncodingVersion = -1
        let container = try makeContainer(rows: [
            existing, versioned, versionedWithProvenance, unknown, unknownWithoutProvenance
        ])
        let beforeMetadata = try metadata(container)
        let beforeValues = try snapshots(container)
        var saveCount = 0
        let bootstrap = LegacyBillingDateProvenanceBootstrap { context in
            saveCount += 1
            try context.save()
        }

        #expect(try bootstrap.execute(container: container, interpretationTimeZone: .gmt) == 0)
        #expect(saveCount == 0)
        #expect(try metadata(container) == beforeMetadata)
        #expect(try snapshots(container) == beforeValues)
    }

    @Test("One batch save uses a dedicated context with autosave disabled")
    func oneBatchSave() throws {
        let container = try makeContainer(rows: [makeRow(), makeRow(), makeRow()])
        var saveCount = 0
        let bootstrap = LegacyBillingDateProvenanceBootstrap { context in
            saveCount += 1
            #expect(context !== container.mainContext)
            #expect(context.autosaveEnabled == false)
            #expect(context.hasChanges)
            try context.save()
            #expect(context.hasChanges == false)
        }
        #expect(try bootstrap.execute(container: container, interpretationTimeZone: .gmt) == 3)
        #expect(saveCount == 1)
    }

    @Test("An empty store never invokes save")
    func emptyStore() throws {
        let container = try makeContainer(rows: [])
        var saveCount = 0
        let bootstrap = LegacyBillingDateProvenanceBootstrap { context in
            saveCount += 1
            try context.save()
        }
        #expect(try bootstrap.execute(container: container, interpretationTimeZone: .gmt) == 0)
        #expect(saveCount == 0)
    }

    @Test("Repeated bootstrap is idempotent even with a different supplied timezone")
    func idempotence() throws {
        let container = try makeContainer(rows: [makeRow(), makeRow()])
        var saveCount = 0
        let bootstrap = LegacyBillingDateProvenanceBootstrap { context in
            saveCount += 1
            try context.save()
        }
        let originalZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
        let newZone = try #require(TimeZone(identifier: "America/New_York"))
        #expect(try bootstrap.execute(container: container, interpretationTimeZone: originalZone) == 2)
        let afterFirst = try metadata(container)
        #expect(try bootstrap.execute(container: container, interpretationTimeZone: newZone) == 0)
        #expect(saveCount == 1)
        #expect(try metadata(container) == afterFirst)
    }

    @Test("The supplied fixed-offset timezone identifier is preserved")
    func suppliedIdentifier() throws {
        let zone = try #require(TimeZone(secondsFromGMT: 3 * 3_600))
        let row = makeRow()
        let id = row.id
        let container = try makeContainer(rows: [row])
        #expect(try LegacyBillingDateProvenanceBootstrap().execute(
            container: container, interpretationTimeZone: zone
        ) == 1)
        #expect(try metadata(container)[id]?.provenance == zone.identifier)
    }

    @Test("Bootstrap cannot save unrelated pending main-context edits")
    func isolatedFromMainContext() throws {
        let row = makeRow()
        let id = row.id
        let originalTitle = row.title
        let container = try makeContainer(rows: [row])
        let main = container.mainContext
        main.autosaveEnabled = false
        let pending = try #require(main.fetch(FetchDescriptor<SDRecurringItem>()).first)
        pending.title = "Uncommitted main-context edit"

        #expect(try LegacyBillingDateProvenanceBootstrap().execute(
            container: container, interpretationTimeZone: .gmt
        ) == 1)
        #expect(main.hasChanges)
        #expect(pending.title == "Uncommitted main-context edit")
        let inspection = ModelContext(container)
        inspection.autosaveEnabled = false
        let persisted = try #require(inspection.fetch(FetchDescriptor<SDRecurringItem>()).first)
        #expect(persisted.id == id)
        #expect(persisted.title == originalTitle)
        #expect(persisted.legacyBillingDateInterpretationTimeZoneIdentifier == TimeZone.gmt.identifier)
        main.rollback()
    }

    @Test("Copied legacy store saves and reopens without changing any billing Date bits or other values")
    func copiedStoreReopens() throws {
        try withCopiedFixture { storeURL in
            let before = try diskState(storeURL)
            try #require(before.metadata.count == 2)
            #expect(before.metadata.values.allSatisfy { $0.version == nil && $0.provenance == nil })
            let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
            #expect(try bootstrapDisk(storeURL, zone: zone) == 2)
            let after = try diskState(storeURL)
            #expect(after.snapshots == before.snapshots)
            #expect(after.metadata.values.allSatisfy { $0.version == nil && $0.provenance == zone.identifier })
            #expect(try bootstrapDisk(storeURL, zone: .gmt) == 0)
            #expect(try diskState(storeURL) == after)
        }
    }

    @Test("Mixed provenance on a temporary fixture copy decodes both original civil intents")
    func mixedProvenanceCopy() throws {
        try withCopiedFixture { storeURL in
            try arrangeNewYorkProvenance(storeURL)
            let before = try diskState(storeURL)
            let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
            #expect(try bootstrapDisk(storeURL, zone: zone) == 1)
            let after = try diskState(storeURL)
            #expect(after.snapshots == before.snapshots)
            #expect(after.metadata[trialID]?.provenance == "Europe/Stockholm")
            #expect(after.metadata[finiteID]?.provenance == "America/New_York")
            #expect(after.metadata.values.allSatisfy { $0.version == nil })
            try verifyFixtureCivilDates(storeURL)
        }
    }

    @Test("A throwing save seam rolls back the dedicated context and a fresh retry succeeds")
    func saveFailureAndRetry() throws {
        try withCopiedFixture { storeURL in
            let container = try makeDiskContainer(storeURL)
            let before = try snapshots(container)
            var attemptedContext: ModelContext?
            var attempts = 0
            let bootstrap = LegacyBillingDateProvenanceBootstrap { context in
                attemptedContext = context
                attempts += 1
                #expect(context.hasChanges)
                throw SimulatedSaveFailure.failed
            }
            let zone = try #require(TimeZone(identifier: "Europe/Stockholm"))
            #expect(throws: SimulatedSaveFailure.failed) {
                try bootstrap.execute(container: container, interpretationTimeZone: zone)
            }
            #expect(attempts == 1)
            let failedContext = try #require(attemptedContext)
            #expect(failedContext.hasChanges == false)
            #expect(try failedContext.fetch(FetchDescriptor<SDRecurringItem>()).allSatisfy {
                $0.legacyBillingDateInterpretationTimeZoneIdentifier == nil
            })
            #expect(try snapshots(container) == before)
            #expect(try metadata(container).values.allSatisfy { $0.provenance == nil })
            #expect(try LegacyBillingDateProvenanceBootstrap().execute(
                container: container, interpretationTimeZone: zone
            ) == 2)
            #expect(try metadata(container).values.allSatisfy { $0.provenance == zone.identifier })
            #expect(try snapshots(container) == before)
        }
    }

    private enum SimulatedSaveFailure: Error { case failed }

    private var trialID: UUID {
        UUID(uuid: (0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x41, 0x11,
                    0x81, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11))
    }

    private var finiteID: UUID {
        UUID(uuid: (0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x42, 0x22,
                    0x82, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22))
    }

    private func makeRow(status: String = "active") -> SDRecurringItem {
        SDRecurringItem(
            id: UUID(), title: "Legacy", providerID: "provider", providerName: "Provider",
            itemTypeRaw: "subscription", categoryRaw: "other", amountValue: 123,
            currencyCode: "SEK", billingCycleRaw: "monthly",
            startDate: Date(timeIntervalSince1970: 1_784_066_400),
            nextChargeDate: Date(timeIntervalSince1970: 1_786_744_800),
            trialEndDate: Date(timeIntervalSince1970: 1_786_744_800),
            autoRenew: false, endDate: Date(timeIntervalSince1970: 1_789_423_200),
            chargeReminderRaw: "threeDaysBefore", trialReminderRaw: "sameDay",
            statusRaw: status, usageStatusRaw: "unknown", paymentMethodID: UUID(),
            note: "Preserve note", tagsRaw: "legacy,trial", isShared: true, isFamilyPlan: true,
            bundleID: UUID(), managementURL: URL(string: "https://example.com/subscription"),
            createdAt: Date(timeIntervalSinceReferenceDate: 1_000_001.25),
            updatedAt: Date(timeIntervalSinceReferenceDate: 1_000_002.5),
            archivedAt: status == "archived" ? Date(timeIntervalSinceReferenceDate: 1_000_003.75) : nil
        )
    }

    private func makeContainer(rows: [SDRecurringItem]) throws -> ModelContainer {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        for row in rows { context.insert(row) }
        try context.save()
        return container
    }

    private func snapshots(_ container: ModelContainer) throws -> [RowSnapshot] {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try context.fetch(FetchDescriptor<SDRecurringItem>())
            .sorted { $0.id.uuidString < $1.id.uuidString }.map(RowSnapshot.init)
    }

    private func metadata(_ container: ModelContainer) throws -> [UUID: Metadata] {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return try Dictionary(uniqueKeysWithValues: context.fetch(FetchDescriptor<SDRecurringItem>()).map {
            ($0.id, Metadata(version: $0.billingDateEncodingVersion,
                             provenance: $0.legacyBillingDateInterpretationTimeZoneIdentifier))
        })
    }

    private func makeDiskContainer(_ storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: SorenModelContainer.schema, url: storeURL, allowsSave: true, cloudKitDatabase: .none
        )
        return try ModelContainer(for: SorenModelContainer.schema, configurations: configuration)
    }

    private func diskState(_ storeURL: URL) throws -> DiskState {
        let container = try makeDiskContainer(storeURL)
        return try DiskState(snapshots: snapshots(container), metadata: metadata(container))
    }

    private func bootstrapDisk(_ storeURL: URL, zone: TimeZone) throws -> Int {
        let container = try makeDiskContainer(storeURL)
        return try LegacyBillingDateProvenanceBootstrap().execute(
            container: container, interpretationTimeZone: zone
        )
    }

    private func arrangeNewYorkProvenance(_ storeURL: URL) throws {
        let container = try makeDiskContainer(storeURL)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let row = try #require(context.fetch(FetchDescriptor<SDRecurringItem>()).first { $0.id == finiteID })
        row.legacyBillingDateInterpretationTimeZoneIdentifier = "America/New_York"
        try context.save()
    }

    private func verifyFixtureCivilDates(_ storeURL: URL) throws {
        let container = try makeDiskContainer(storeURL)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let adapter = RecurringItemBillingDateAdapter()
        for row in try context.fetch(FetchDescriptor<SDRecurringItem>()) {
            let output = try adapter.decode(
                .init(startDate: row.startDate, nextChargeDate: row.nextChargeDate,
                      trialEndDate: row.trialEndDate, endDate: row.endDate),
                itemID: row.id, encodingVersion: row.billingDateEncodingVersion,
                legacyTimeZoneIdentifier: row.legacyBillingDateInterpretationTimeZoneIdentifier
            )
            if row.id == trialID {
                #expect(output.startDate == Date(timeIntervalSince1970: 1_784_073_600))
                #expect(output.nextChargeDate == Date(timeIntervalSince1970: 1_786_752_000))
                #expect(output.trialEndDate == output.nextChargeDate)
                #expect(output.endDate == nil)
            } else {
                #expect(row.id == finiteID)
                #expect(output.startDate == Date(timeIntervalSince1970: 1_672_531_200))
                #expect(output.nextChargeDate == Date(timeIntervalSince1970: 1_767_225_600))
                #expect(output.trialEndDate == nil)
                #expect(output.endDate == output.nextChargeDate)
            }
        }
    }

    private func withCopiedFixture(_ body: (URL) throws -> Void) throws {
        let source = try #require(Bundle(for: BootstrapFixtureBundleMarker.self).url(
            forResource: "CivilDateLegacyV1", withExtension: "fixture"
        ))
        let sourceBefore = try sourceSnapshot(source)
        try verifySource(sourceBefore)
        defer {
            do {
                let sourceAfter = try sourceSnapshot(source)
                try verifySource(sourceAfter)
                #expect(sourceAfter == sourceBefore)
            } catch {
                Issue.record("Immutable source fixture verification failed: \(error)")
            }
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: temporary) }
            catch { Issue.record("Temporary fixture cleanup failed: \(error)") }
        }
        let copy = temporary.appendingPathComponent("CivilDateLegacyV1.fixture", isDirectory: true)
        try FileManager.default.copyItem(at: source, to: copy)
        try body(copy.appendingPathComponent("default.store"))
    }

    private func sourceSnapshot(_ directory: URL) throws -> SourceSnapshot {
        try SourceSnapshot(
            names: FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(),
            store: Data(contentsOf: directory.appendingPathComponent("default.store")),
            manifest: Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        )
    }

    private func verifySource(_ snapshot: SourceSnapshot) throws {
        try #require(snapshot.names == ["default.store", "manifest.json"])
        try #require(sha256(snapshot.store) == "5452bcc67ba007ffe9c71ea75c79ccde9d64346f4541e50fc25edf15f762d25b")
        try #require(sha256(snapshot.manifest) == "5aed974e3df837426d5d5d4d26d81504d7952aa7f47878b4a4f68f9ccd83fa2e")
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private final class BootstrapFixtureBundleMarker: NSObject { }

private struct Metadata: Equatable {
    let version: Int?
    let provenance: String?
}

private struct DiskState: Equatable {
    let snapshots: [RowSnapshot]
    let metadata: [UUID: Metadata]
}

private struct SourceSnapshot: Equatable {
    let names: [String]
    let store: Data
    let manifest: Data
}

/// Every persisted scalar except provenance is captured, including exact Date bit patterns.
/// Relationships are checked by identity without invoking the production Domain mapper.
private struct RowSnapshot: Equatable {
    let ids: [UUID?]
    let text: [String?]
    let amount: Decimal
    let flags: [Bool?]
    let dateBits: [UInt64?]
    let version: Int?
    let managementURL: URL?
    let paymentIDs: [UUID]
    let reminderIDs: [UUID]

    @MainActor
    init(_ row: SDRecurringItem) {
        ids = [row.id, row.paymentMethodID, row.bundleID]
        text = [row.title, row.providerID, row.providerName, row.itemTypeRaw, row.categoryRaw,
                row.currencyCode, row.billingCycleRaw, row.chargeReminderRaw, row.trialReminderRaw,
                row.statusRaw, row.usageStatusRaw, row.note, row.tagsRaw]
        amount = row.amountValue
        flags = [row.autoRenew, row.isShared, row.isFamilyPlan]
        dateBits = [row.startDate, row.nextChargeDate, row.trialEndDate, row.endDate,
                    row.createdAt, row.updatedAt, row.archivedAt]
            .map { $0?.timeIntervalSinceReferenceDate.bitPattern }
        version = row.billingDateEncodingVersion
        managementURL = row.managementURL
        paymentIDs = row.payments.map(\.id).sorted { $0.uuidString < $1.uuidString }
        reminderIDs = row.reminders.map(\.id).sorted { $0.uuidString < $1.uuidString }
    }
}
