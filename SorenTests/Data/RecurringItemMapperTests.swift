import Testing
import Foundation
import SwiftData
@testable import Soren

@Suite("RecurringItemMapper — domain ↔ persistence conversion")
struct RecurringItemMapperTests {

    // MARK: - toDomain

    @Test("toDomain preserves all scalar fields")
    func toDomainPreservesScalars() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)

        let id = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let sd = SDRecurringItem(
            id: id,
            title: "Netflix",
            providerID: "netflix",
            providerName: "Netflix Inc.",
            itemTypeRaw: "subscription",
            categoryRaw: "video",
            amountValue: 699,
            currencyCode: "RUB",
            billingCycleRaw: "monthly",
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            nextChargeDate: Date(timeIntervalSinceReferenceDate: 0),
            trialEndDate: nil,
            statusRaw: "active",
            usageStatusRaw: "frequentlyUsed",
            paymentMethodID: nil,
            note: "Test note",
            tagsRaw: "Annual,Family",
            isShared: true,
            isFamilyPlan: true,
            bundleID: nil,
            managementURL: nil,
            createdAt: now,
            updatedAt: now,
            archivedAt: nil
        )
        sd.billingDateEncodingVersion = 1
        context.insert(sd)

        let domain = try RecurringItemMapper.toDomain(sd)

        #expect(domain.id == id)
        #expect(domain.title == "Netflix")
        #expect(domain.providerID == "netflix")
        #expect(domain.providerName == "Netflix Inc.")
        #expect(domain.itemType == .subscription)
        #expect(domain.category == .video)
        #expect(domain.amount == 699)
        #expect(domain.currencyCode == "RUB")
        #expect(domain.billingCycle == .monthly)
        #expect(domain.status == .active)
        #expect(domain.usageStatus == .frequentlyUsed)
        #expect(domain.note == "Test note")
        #expect(domain.tags == ["Annual", "Family"])
        #expect(domain.isShared == true)
        #expect(domain.isFamilyPlan == true)
    }

    @Test("toDomain falls back for unknown itemType")
    func toDomainUnknownItemType() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)
        let sd = makeSDItem(context: context, itemTypeRaw: "totally_unknown_type")
        let domain = try RecurringItemMapper.toDomain(sd)
        #expect(domain.itemType == .otherRecurring)
    }

    @Test("toDomain falls back for unknown status")
    func toDomainUnknownStatus() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)
        let sd = makeSDItem(context: context, statusRaw: "???")
        let domain = try RecurringItemMapper.toDomain(sd)
        #expect(domain.status == .active)
    }

    @Test("toDomain falls back for unknown category")
    func toDomainUnknownCategory() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)
        let sd = makeSDItem(context: context, categoryRaw: "not_a_category")
        let domain = try RecurringItemMapper.toDomain(sd)
        #expect(domain.category == .other)
    }

    // MARK: - toSD

    @Test("toSD then toDomain round-trips all core fields")
    func roundTrip() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)

        let original = RecurringItem(
            id: UUID(),
            title: "Яндекс Плюс",
            providerID: "yandex_plus",
            providerName: "Яндекс",
            itemType: .ecosystemBundle,
            category: .shopping,
            amount: 399,
            currencyCode: "RUB",
            billingCycle: .monthly,
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            nextChargeDate: Date(timeIntervalSinceReferenceDate: 0),
            status: .active,
            usageStatus: .frequentlyUsed,
            tags: ["Bundle", "Family"],
            isShared: false,
            isFamilyPlan: true
        )

        let sd = try RecurringItemMapper.toSD(original)
        context.insert(sd)
        let restored = try RecurringItemMapper.toDomain(sd)

        #expect(restored.id == original.id)
        #expect(restored.title == original.title)
        #expect(restored.providerID == original.providerID)
        #expect(restored.itemType == original.itemType)
        #expect(restored.category == original.category)
        #expect(restored.amount == original.amount)
        #expect(restored.currencyCode == original.currencyCode)
        #expect(restored.billingCycle == original.billingCycle)
        #expect(restored.status == original.status)
        #expect(restored.tags == original.tags)
        #expect(restored.isFamilyPlan == original.isFamilyPlan)
    }

    @Test("round-trip preserves custom billing cycle with specific days")
    func roundTripCustomCycle() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)

        let item = RecurringItem(
            title: "Custom",
            amount: 100,
            billingCycle: .custom(days: 14),
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            nextChargeDate: Date(timeIntervalSinceReferenceDate: 0)
        )
        let sd = try RecurringItemMapper.toSD(item)
        context.insert(sd)
        let restored = try RecurringItemMapper.toDomain(sd)
        #expect(restored.billingCycle == .custom(days: 14))
    }

    // MARK: - update

    @Test("update mutates SD object with domain changes")
    func updateMutatesSD() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)

        var domain = RecurringItem(
            title: "Old Title",
            amount: 100,
            startDate: Date(timeIntervalSinceReferenceDate: 0),
            nextChargeDate: Date(timeIntervalSinceReferenceDate: 0)
        )
        let sd = try RecurringItemMapper.toSD(domain)
        context.insert(sd)

        domain.title = "New Title"
        domain.amount = 999
        try RecurringItemMapper.update(sd, from: domain)

        #expect(sd.title == "New Title")
        #expect(sd.amountValue == 999)
    }

    @Test("update does not change the id field")
    func updatePreservesID() throws {
        let container = try SorenModelContainer.inMemory()
        let context = ModelContext(container)

        let originalID = UUID()
        let domain = RecurringItem(id: originalID, title: "Test", amount: 100, startDate: Date(timeIntervalSinceReferenceDate: 0),
            nextChargeDate: Date(timeIntervalSinceReferenceDate: 0))
        let sd = try RecurringItemMapper.toSD(domain)
        context.insert(sd)

        // Simulate update with a different domain (same id but changed data)
        var updated = domain
        updated.title = "Changed"
        try RecurringItemMapper.update(sd, from: updated)

        // id must never change
        #expect(sd.id == originalID)
    }
}

// MARK: - Helpers

private func makeSDItem(
    context: ModelContext,
    itemTypeRaw: String = "subscription",
    statusRaw: String = "active",
    categoryRaw: String = "video"
) -> SDRecurringItem {
    let sd = SDRecurringItem(
        id: UUID(),
        title: "Test",
        providerID: nil,
        providerName: "Test",
        itemTypeRaw: itemTypeRaw,
        categoryRaw: categoryRaw,
        amountValue: 100,
        currencyCode: "RUB",
        billingCycleRaw: "monthly",
        startDate: Date(timeIntervalSinceReferenceDate: 0),
        nextChargeDate: Date(timeIntervalSinceReferenceDate: 0),
        trialEndDate: nil,
        statusRaw: statusRaw,
        usageStatusRaw: "unknown",
        paymentMethodID: nil,
        note: "",
        tagsRaw: "",
        isShared: false,
        isFamilyPlan: false,
        bundleID: nil,
        managementURL: nil,
        createdAt: .now,
        updatedAt: .now,
        archivedAt: nil
    )
    sd.billingDateEncodingVersion = 1
    context.insert(sd)
    return sd
}
