import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import Soren

@Suite("SwiftData legacy-store compatibility")
@MainActor
struct SwiftDataLegacyStoreCompatibilityTests {
    @Test("Fresh current-schema store defaults metadata to nil and reopens")
    func diskStoreReopensAfterOwnersAreReleased() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("default.store")
            let writeOwnership = StoreOwnership()

            try writeCurrentSchemaStore(at: storeURL, tracking: writeOwnership)

            #expect(writeOwnership.container == nil)
            #expect(writeOwnership.context == nil)

            let readOwnership = StoreOwnership()
            try verifyCurrentSchemaStore(at: storeURL, tracking: readOwnership)

            #expect(readOwnership.container == nil)
            #expect(readOwnership.context == nil)
        }
    }

    @Test("Immutable V1 fixture opens and reopens under the evolved schema")
    func bundledV1FixtureOpensFromCopy() throws {
        try withCopiedLegacyFixture { storeURL in
            let firstOwnership = StoreOwnership()
            try verifyCurrentSchemaStore(
                at: storeURL,
                tracking: firstOwnership
            )

            #expect(firstOwnership.container == nil)
            #expect(firstOwnership.context == nil)

            let secondOwnership = StoreOwnership()
            try verifyCurrentSchemaStore(
                at: storeURL,
                tracking: secondOwnership
            )

            #expect(secondOwnership.container == nil)
            #expect(secondOwnership.context == nil)
        }
    }

    @Test("Metadata persists on a copied V1 store without changing legacy fields")
    func metadataPersistsOnCopiedV1Fixture() throws {
        try withCopiedLegacyFixture { storeURL in
            let targetID = try #require(LegacyV1Fixture.records.first?.id)
            let expectedMetadata = BillingDateMetadata(
                encodingVersion: 1,
                interpretationTimeZoneIdentifier: "Europe/Stockholm"
            )
            let writeOwnership = StoreOwnership()

            try writeMetadata(
                expectedMetadata,
                toItemWithID: targetID,
                at: storeURL,
                tracking: writeOwnership
            )

            #expect(writeOwnership.container == nil)
            #expect(writeOwnership.context == nil)

            let readOwnership = StoreOwnership()
            try verifyCurrentSchemaStore(
                at: storeURL,
                expectedMetadataByID: [targetID: expectedMetadata],
                tracking: readOwnership
            )

            #expect(readOwnership.container == nil)
            #expect(readOwnership.context == nil)
        }
    }

    private func writeCurrentSchemaStore(
        at storeURL: URL,
        tracking ownership: StoreOwnership
    ) throws {
        let container = try makeContainer(at: storeURL)
        let context = container.mainContext
        ownership.container = container
        ownership.context = context

        for record in LegacyV1Fixture.records {
            context.insert(record.makeModel())
        }
        try context.save()
    }

    private func writeMetadata(
        _ metadata: BillingDateMetadata,
        toItemWithID itemID: UUID,
        at storeURL: URL,
        tracking ownership: StoreOwnership
    ) throws {
        let container = try makeContainer(at: storeURL)
        let context = container.mainContext
        ownership.container = container
        ownership.context = context
        let models = try fetchVerifiedLegacyModels(from: context)

        for model in models {
            #expect(BillingDateMetadata(model) == .legacy)
        }

        let target = try #require(models.first { $0.id == itemID })
        target.billingDateEncodingVersion = metadata.encodingVersion
        target.legacyBillingDateInterpretationTimeZoneIdentifier =
            metadata.interpretationTimeZoneIdentifier
        try context.save()
    }

    private func verifyCurrentSchemaStore(
        at storeURL: URL,
        expectedMetadataByID: [UUID: BillingDateMetadata] = [:],
        tracking ownership: StoreOwnership
    ) throws {
        let container = try makeContainer(at: storeURL)
        let context = container.mainContext
        ownership.container = container
        ownership.context = context
        let models = try fetchVerifiedLegacyModels(from: context)

        for model in models {
            let expectedMetadata = expectedMetadataByID[model.id] ?? .legacy
            #expect(BillingDateMetadata(model) == expectedMetadata)
        }
    }

    private func fetchVerifiedLegacyModels(
        from context: ModelContext
    ) throws -> [SDRecurringItem] {
        let models = try context.fetch(FetchDescriptor<SDRecurringItem>())
        let records = models.map(LegacyRecurringItemRecord.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }

        #expect(records == LegacyV1Fixture.records)
        return models
    }

    private func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: SorenModelContainer.schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: SorenModelContainer.schema,
            configurations: configuration
        )
    }

    private func withTemporaryDirectory<T>(
        _ body: (URL) throws -> T
    ) throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record("Could not remove temporary store: \(error)")
            }
        }
        return try body(directory)
    }

    private func withCopiedLegacyFixture(
        _ body: (URL) throws -> Void
    ) throws {
        let sourceFixture = try #require(
            Bundle(for: LegacyFixtureBundleMarker.self).url(
                forResource: "CivilDateLegacyV1",
                withExtension: "fixture"
            )
        )
        let sourceBefore = try fixtureSnapshot(at: sourceFixture)
        verifyAuthoritativeFixture(sourceBefore)

        defer {
            do {
                let sourceAfter = try fixtureSnapshot(at: sourceFixture)
                verifyAuthoritativeFixture(sourceAfter)
                #expect(sourceAfter == sourceBefore)
            } catch {
                Issue.record("Could not verify immutable V1 fixture: \(error)")
            }
        }

        try withTemporaryDirectory { directory in
            let copiedFixture = directory.appendingPathComponent(
                "CivilDateLegacyV1.fixture",
                isDirectory: true
            )
            try FileManager.default.copyItem(at: sourceFixture, to: copiedFixture)
            try body(copiedFixture.appendingPathComponent("default.store"))
        }
    }

    private func fixtureSnapshot(at fixtureURL: URL) throws -> FixtureSnapshot {
        FixtureSnapshot(
            fileNames: try FileManager.default.contentsOfDirectory(
                atPath: fixtureURL.path
            ).sorted(),
            store: try Data(
                contentsOf: fixtureURL.appendingPathComponent("default.store")
            ),
            manifest: try Data(
                contentsOf: fixtureURL.appendingPathComponent("manifest.json")
            )
        )
    }

    private func verifyAuthoritativeFixture(_ fixture: FixtureSnapshot) {
        #expect(fixture.fileNames == ["default.store", "manifest.json"])
        #expect(
            sha256(fixture.store) == LegacyV1Fixture.authoritativeStoreSHA256
        )
        #expect(
            sha256(fixture.manifest)
                == LegacyV1Fixture.authoritativeManifestSHA256
        )
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

@MainActor
private final class StoreOwnership {
    weak var container: ModelContainer?
    weak var context: ModelContext?
}

private final class LegacyFixtureBundleMarker: NSObject { }

private struct BillingDateMetadata: Equatable {
    let encodingVersion: Int?
    let interpretationTimeZoneIdentifier: String?

    init(
        encodingVersion: Int?,
        interpretationTimeZoneIdentifier: String?
    ) {
        self.encodingVersion = encodingVersion
        self.interpretationTimeZoneIdentifier =
            interpretationTimeZoneIdentifier
    }

    init(_ model: SDRecurringItem) {
        self.init(
            encodingVersion: model.billingDateEncodingVersion,
            interpretationTimeZoneIdentifier:
                model.legacyBillingDateInterpretationTimeZoneIdentifier
        )
    }

    static let legacy = BillingDateMetadata(
        encodingVersion: nil,
        interpretationTimeZoneIdentifier: nil
    )
}

private struct FixtureSnapshot: Equatable {
    let fileNames: [String]
    let store: Data
    let manifest: Data
}

private enum LegacyV1Fixture {
    static let authoritativeStoreSHA256 =
        "5452bcc67ba007ffe9c71ea75c79ccde9d64346f4541e50fc25edf15f762d25b"
    static let authoritativeManifestSHA256 =
        "5aed974e3df837426d5d5d4d26d81504d7952aa7f47878b4a4f68f9ccd83fa2e"

    static let records: [LegacyRecurringItemRecord] = [
        LegacyRecurringItemRecord(
            id: UUID(uuid: (
                0x11, 0x11, 0x11, 0x11,
                0x11, 0x11, 0x41, 0x11,
                0x81, 0x11, 0x11, 0x11,
                0x11, 0x11, 0x11, 0x11
            )),
            title: "Legacy Trial",
            providerID: "apple_music",
            providerName: "Apple Music",
            itemTypeRaw: ItemType.trial.rawValue,
            categoryRaw: ItemCategory.music.rawValue,
            amountValue: Decimal(199),
            currencyCode: "SEK",
            billingCycleRaw: BillingCycleEncoder.encode(.monthly),
            startDate: Date(timeIntervalSince1970: 1_784_066_400),
            nextChargeDate: Date(timeIntervalSince1970: 1_786_744_800),
            trialEndDate: Date(timeIntervalSince1970: 1_786_744_800),
            autoRenew: true,
            endDate: nil,
            chargeReminderRaw: ChargeReminderOption.threeDaysBefore.rawValue,
            trialReminderRaw: TrialReminderOption.oneDayBefore.rawValue,
            statusRaw: ItemStatus.trial.rawValue,
            usageStatusRaw: UsageStatus.frequentlyUsed.rawValue,
            paymentMethodID: UUID(uuid: (
                0xAA, 0xAA, 0xAA, 0xAA,
                0xAA, 0xAA, 0x4A, 0xAA,
                0x8A, 0xAA, 0xAA, 0xAA,
                0xAA, 0xAA, 0xAA, 0xAA
            )),
            note: "Pre-migration trial record",
            tagsRaw: "music,trial",
            isShared: true,
            isFamilyPlan: true,
            bundleID: UUID(uuid: (
                0xBB, 0xBB, 0xBB, 0xBB,
                0xBB, 0xBB, 0x4B, 0xBB,
                0x8B, 0xBB, 0xBB, 0xBB,
                0xBB, 0xBB, 0xBB, 0xBB
            )),
            managementURL: URL(string: "https://example.com/trial"),
            createdAt: Date(timeIntervalSince1970: 1_785_024_000),
            updatedAt: Date(timeIntervalSince1970: 1_785_110_400),
            archivedAt: nil,
            paymentCount: 0,
            reminderCount: 0
        ),
        LegacyRecurringItemRecord(
            id: UUID(uuid: (
                0x22, 0x22, 0x22, 0x22,
                0x22, 0x22, 0x42, 0x22,
                0x82, 0x22, 0x22, 0x22,
                0x22, 0x22, 0x22, 0x22
            )),
            title: "Legacy Finite Archive",
            providerID: nil,
            providerName: "Legacy Provider",
            itemTypeRaw: ItemType.subscription.rawValue,
            categoryRaw: ItemCategory.productivity.rawValue,
            amountValue: Decimal(49),
            currencyCode: "USD",
            billingCycleRaw: BillingCycleEncoder.encode(.annual),
            startDate: Date(timeIntervalSince1970: 1_672_549_200),
            nextChargeDate: Date(timeIntervalSince1970: 1_767_243_600),
            trialEndDate: nil,
            autoRenew: false,
            endDate: Date(timeIntervalSince1970: 1_767_243_600),
            chargeReminderRaw: ChargeReminderOption.never.rawValue,
            trialReminderRaw: nil,
            statusRaw: ItemStatus.archived.rawValue,
            usageStatusRaw: UsageStatus.unused.rawValue,
            paymentMethodID: nil,
            note: "Pre-migration finite record",
            tagsRaw: "legacy,finite",
            isShared: false,
            isFamilyPlan: false,
            bundleID: nil,
            managementURL: nil,
            createdAt: Date(timeIntervalSince1970: 1_672_531_200),
            updatedAt: Date(timeIntervalSince1970: 1_735_689_600),
            archivedAt: Date(timeIntervalSince1970: 1_735_776_000),
            paymentCount: 0,
            reminderCount: 0
        ),
    ]
    .sorted { $0.id.uuidString < $1.id.uuidString }
}

private struct LegacyRecurringItemRecord: Equatable {
    let id: UUID
    let title: String
    let providerID: String?
    let providerName: String
    let itemTypeRaw: String
    let categoryRaw: String
    let amountValue: Decimal
    let currencyCode: String
    let billingCycleRaw: String
    let startDate: Date
    let nextChargeDate: Date
    let trialEndDate: Date?
    let autoRenew: Bool?
    let endDate: Date?
    let chargeReminderRaw: String?
    let trialReminderRaw: String?
    let statusRaw: String
    let usageStatusRaw: String
    let paymentMethodID: UUID?
    let note: String
    let tagsRaw: String
    let isShared: Bool
    let isFamilyPlan: Bool
    let bundleID: UUID?
    let managementURL: URL?
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?
    let paymentCount: Int
    let reminderCount: Int

    init(
        id: UUID,
        title: String,
        providerID: String?,
        providerName: String,
        itemTypeRaw: String,
        categoryRaw: String,
        amountValue: Decimal,
        currencyCode: String,
        billingCycleRaw: String,
        startDate: Date,
        nextChargeDate: Date,
        trialEndDate: Date?,
        autoRenew: Bool?,
        endDate: Date?,
        chargeReminderRaw: String?,
        trialReminderRaw: String?,
        statusRaw: String,
        usageStatusRaw: String,
        paymentMethodID: UUID?,
        note: String,
        tagsRaw: String,
        isShared: Bool,
        isFamilyPlan: Bool,
        bundleID: UUID?,
        managementURL: URL?,
        createdAt: Date,
        updatedAt: Date,
        archivedAt: Date?,
        paymentCount: Int,
        reminderCount: Int
    ) {
        self.id = id
        self.title = title
        self.providerID = providerID
        self.providerName = providerName
        self.itemTypeRaw = itemTypeRaw
        self.categoryRaw = categoryRaw
        self.amountValue = amountValue
        self.currencyCode = currencyCode
        self.billingCycleRaw = billingCycleRaw
        self.startDate = startDate
        self.nextChargeDate = nextChargeDate
        self.trialEndDate = trialEndDate
        self.autoRenew = autoRenew
        self.endDate = endDate
        self.chargeReminderRaw = chargeReminderRaw
        self.trialReminderRaw = trialReminderRaw
        self.statusRaw = statusRaw
        self.usageStatusRaw = usageStatusRaw
        self.paymentMethodID = paymentMethodID
        self.note = note
        self.tagsRaw = tagsRaw
        self.isShared = isShared
        self.isFamilyPlan = isFamilyPlan
        self.bundleID = bundleID
        self.managementURL = managementURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.paymentCount = paymentCount
        self.reminderCount = reminderCount
    }

    init(_ model: SDRecurringItem) {
        self.init(
            id: model.id,
            title: model.title,
            providerID: model.providerID,
            providerName: model.providerName,
            itemTypeRaw: model.itemTypeRaw,
            categoryRaw: model.categoryRaw,
            amountValue: model.amountValue,
            currencyCode: model.currencyCode,
            billingCycleRaw: model.billingCycleRaw,
            startDate: model.startDate,
            nextChargeDate: model.nextChargeDate,
            trialEndDate: model.trialEndDate,
            autoRenew: model.autoRenew,
            endDate: model.endDate,
            chargeReminderRaw: model.chargeReminderRaw,
            trialReminderRaw: model.trialReminderRaw,
            statusRaw: model.statusRaw,
            usageStatusRaw: model.usageStatusRaw,
            paymentMethodID: model.paymentMethodID,
            note: model.note,
            tagsRaw: model.tagsRaw,
            isShared: model.isShared,
            isFamilyPlan: model.isFamilyPlan,
            bundleID: model.bundleID,
            managementURL: model.managementURL,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            archivedAt: model.archivedAt,
            paymentCount: model.payments.count,
            reminderCount: model.reminders.count
        )
    }

    func makeModel() -> SDRecurringItem {
        SDRecurringItem(
            id: id,
            title: title,
            providerID: providerID,
            providerName: providerName,
            itemTypeRaw: itemTypeRaw,
            categoryRaw: categoryRaw,
            amountValue: amountValue,
            currencyCode: currencyCode,
            billingCycleRaw: billingCycleRaw,
            startDate: startDate,
            nextChargeDate: nextChargeDate,
            trialEndDate: trialEndDate,
            autoRenew: autoRenew,
            endDate: endDate,
            chargeReminderRaw: chargeReminderRaw,
            trialReminderRaw: trialReminderRaw,
            statusRaw: statusRaw,
            usageStatusRaw: usageStatusRaw,
            paymentMethodID: paymentMethodID,
            note: note,
            tagsRaw: tagsRaw,
            isShared: isShared,
            isFamilyPlan: isFamilyPlan,
            bundleID: bundleID,
            managementURL: managementURL,
            createdAt: createdAt,
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
    }
}
