import Foundation
import SwiftData
import Testing
@testable import Soren

@Suite("SwiftData legacy-store compatibility")
@MainActor
struct SwiftDataLegacyStoreCompatibilityTests {
    @Test("Disk store survives full container release and reopen")
    func diskStoreReopensAfterOwnersAreReleased() throws {
        try withTemporaryDirectory { directory in
            let storeURL = directory.appendingPathComponent("default.store")
            let ownership = StoreOwnership()

            try writeCurrentSchemaStore(at: storeURL, tracking: ownership)

            #expect(ownership.container == nil)
            #expect(ownership.context == nil)

            try verifyCurrentSchemaStore(at: storeURL)
        }
    }

    @Test("Immutable V1 fixture opens successfully from a copy")
    func bundledV1FixtureOpensFromCopy() throws {
        let sourceFixture = try #require(
            Bundle(for: LegacyFixtureBundleMarker.self).url(
                forResource: "CivilDateLegacyV1",
                withExtension: "fixture"
            )
        )
        let sourceStore = sourceFixture.appendingPathComponent("default.store")
        let sourceManifest = sourceFixture.appendingPathComponent("manifest.json")
        let sourceFilesBefore = try FileManager.default.contentsOfDirectory(
            atPath: sourceFixture.path
        ).sorted()
        let sourceStoreBefore = try Data(contentsOf: sourceStore)
        let sourceManifestBefore = try Data(contentsOf: sourceManifest)

        #expect(sourceFilesBefore == ["default.store", "manifest.json"])

        try withTemporaryDirectory { directory in
            let copiedFixture = directory.appendingPathComponent(
                "CivilDateLegacyV1.fixture",
                isDirectory: true
            )
            try FileManager.default.copyItem(at: sourceFixture, to: copiedFixture)
            try verifyCurrentSchemaStore(
                at: copiedFixture.appendingPathComponent("default.store")
            )
        }

        #expect(try Data(contentsOf: sourceStore) == sourceStoreBefore)
        #expect(try Data(contentsOf: sourceManifest) == sourceManifestBefore)
        #expect(
            try FileManager.default.contentsOfDirectory(
                atPath: sourceFixture.path
            ).sorted() == sourceFilesBefore
        )
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

    private func verifyCurrentSchemaStore(at storeURL: URL) throws {
        let container = try makeContainer(at: storeURL)
        let context = container.mainContext
        let models = try context.fetch(FetchDescriptor<SDRecurringItem>())
        let records = models.map(LegacyRecurringItemRecord.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }

        #expect(records == LegacyV1Fixture.records)
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
}

@MainActor
private final class StoreOwnership {
    weak var container: ModelContainer?
    weak var context: ModelContext?
}

private final class LegacyFixtureBundleMarker: NSObject { }

private enum LegacyV1Fixture {
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
