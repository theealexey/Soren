import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Repository Tests (Aggressive)

/// These tests are adversarial. They try to break the repository, not just confirm happy paths.
/// Every test creates a fresh in-memory container to guarantee isolation.

@Suite("RecurringItemRepository")
@MainActor
struct RecurringItemRepositoryTests {

    // MARK: - Helpers

    private func makeRepo() throws -> (SwiftDataRecurringItemRepository, ModelContext) {
        let container = try SorenModelContainer.inMemory()
        let context = container.mainContext
        return (SwiftDataRecurringItemRepository(context: context), context)
    }

    private func makeItem(
        title: String = "Netflix",
        status: ItemStatus = .active,
        nextCharge: Date = .now,
        category: ItemCategory = .video,
        archived: Bool = false
    ) -> RecurringItem {
        RecurringItem(
            id: UUID(),
            title: title,
            providerID: nil,
            providerName: title,
            itemType: .subscription,
            category: category,
            amount: 9.99,
            currencyCode: "USD",
            billingCycle: .monthly,
            startDate: .now,
            nextChargeDate: nextCharge,
            trialEndDate: nil,
            status: status,
            usageStatus: .unknown,
            paymentMethodID: nil,
            note: "",
            tags: [],
            isShared: false,
            isFamilyPlan: false,
            bundleID: nil,
            managementURL: nil,
            createdAt: .now,
            updatedAt: .now,
            archivedAt: archived ? .now : nil
        )
    }

    // MARK: - Basic CRUD

    @Test("save and fetch by ID roundtrips correctly")
    func saveAndFetchByID() throws {
        let (repo, _) = try makeRepo()
        let item = makeItem(title: "Spotify")

        try repo.save(item)
        let fetched = try repo.fetch(id: item.id)

        #expect(fetched?.id == item.id)
        #expect(fetched?.title == "Spotify")
        #expect(fetched?.currencyCode == "USD")
    }

    @Test("fetch unknown ID returns nil, not a crash")
    func fetchUnknownID() throws {
        let (repo, _) = try makeRepo()
        let result = try repo.fetch(id: UUID())
        #expect(result == nil)
    }

    @Test("save duplicate ID throws or silently overwrites — never corrupts")
    func saveDuplicateID() throws {
        let (repo, _) = try makeRepo()
        let item = makeItem(title: "Original")
        try repo.save(item)

        // Saving same ID again should not leave two records
        let duplicate = RecurringItem(
            id: item.id, title: "Duplicate", providerID: nil, providerName: "Dup",
            itemType: .subscription, category: .video, amount: 1.00, currencyCode: "USD",
            billingCycle: .monthly, startDate: .now, nextChargeDate: .now,
            trialEndDate: nil, status: .active, usageStatus: .unknown,
            paymentMethodID: nil, note: "", tags: [], isShared: false, isFamilyPlan: false,
            bundleID: nil, managementURL: nil, createdAt: .now, updatedAt: .now, archivedAt: nil
        )
        // We expect either a throw or upsert — never two items with same ID
        let _ = try? repo.save(duplicate)
        let all = try repo.fetchAll()
        let matching = all.filter { $0.id == item.id }
        #expect(matching.count <= 1)
    }

    @Test("update changes title and amount correctly")
    func updateItem() throws {
        let (repo, _) = try makeRepo()
        var item = makeItem(title: "Old Title")
        try repo.save(item)

        item = RecurringItem(
            id: item.id, title: "New Title", providerID: nil, providerName: "New",
            itemType: item.itemType, category: item.category, amount: 19.99,
            currencyCode: item.currencyCode, billingCycle: item.billingCycle,
            startDate: item.startDate, nextChargeDate: item.nextChargeDate,
            trialEndDate: nil, status: item.status, usageStatus: item.usageStatus,
            paymentMethodID: nil, note: "", tags: [], isShared: false, isFamilyPlan: false,
            bundleID: nil, managementURL: nil, createdAt: item.createdAt,
            updatedAt: .now, archivedAt: nil
        )
        try repo.update(item)

        let fetched = try repo.fetch(id: item.id)
        #expect(fetched?.title == "New Title")
        #expect(fetched?.amount == 19.99)
    }

    @Test("update non-existent ID throws RepositoryError.notFound")
    func updateNonExistent() throws {
        let (repo, _) = try makeRepo()
        let ghost = makeItem(title: "Ghost")

        #expect(throws: RepositoryError.self) {
            try repo.update(ghost)
        }
    }

    @Test("delete removes item and subsequent fetch returns nil")
    func deleteItem() throws {
        let (repo, _) = try makeRepo()
        let item = makeItem()
        try repo.save(item)
        try repo.delete(id: item.id)

        let fetched = try repo.fetch(id: item.id)
        #expect(fetched == nil)
    }

    @Test("delete non-existent ID does not throw")
    func deleteNonExistent() throws {
        let (repo, _) = try makeRepo()
        // Should not throw — idempotent delete
        #expect(throws: Never.self) {
            try repo.delete(id: UUID())
        }
    }

    // MARK: - Fetch Filters

    @Test("fetchActive excludes archived items")
    func fetchActiveExcludesArchived() throws {
        let (repo, _) = try makeRepo()
        try repo.save(makeItem(title: "Active", archived: false))
        try repo.save(makeItem(title: "Archived", archived: true))

        let active = try repo.fetchActive()
        #expect(active.count == 1)
        #expect(active[0].title == "Active")
    }

    @Test("fetchActive excludes cancelled and paused statuses")
    func fetchActiveExcludesCancelled() throws {
        let (repo, _) = try makeRepo()
        try repo.save(makeItem(title: "A", status: .active))
        try repo.save(makeItem(title: "B", status: .cancelled))
        try repo.save(makeItem(title: "C", status: .paused))
        try repo.save(makeItem(title: "D", status: .trial))

        let active = try repo.fetchActive()
        let titles = active.map(\.title).sorted()
        #expect(titles == ["A", "D"])
    }

    @Test("fetchUpcoming with 7 days returns only items in window")
    func fetchUpcomingWindow() throws {
        let (repo, _) = try makeRepo()
        let now = Date()
        let cal = Calendar.current

        let tomorrow = cal.date(byAdding: .day, value: 1, to: now)!
        let in10 = cal.date(byAdding: .day, value: 10, to: now)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!

        try repo.save(makeItem(title: "Tomorrow", nextCharge: tomorrow))
        try repo.save(makeItem(title: "In10", nextCharge: in10))
        try repo.save(makeItem(title: "Yesterday", nextCharge: yesterday))

        let upcoming = try repo.fetchUpcoming(within: 7, from: now)
        #expect(upcoming.count == 1)
        #expect(upcoming[0].title == "Tomorrow")
    }

    @Test("fetchUpcoming with 0 days returns empty")
    func fetchUpcomingZeroDays() throws {
        let (repo, _) = try makeRepo()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        try repo.save(makeItem(nextCharge: tomorrow))

        let result = try repo.fetchUpcoming(within: 0, from: .now)
        #expect(result.isEmpty)
    }

    @Test("fetchByCategory returns only matching category")
    func fetchByCategory() throws {
        let (repo, _) = try makeRepo()
        try repo.save(makeItem(title: "Netflix", category: .video))
        try repo.save(makeItem(title: "Spotify", category: .music))
        try repo.save(makeItem(title: "YouTube", category: .video))

        let video = try repo.fetchByCategory(.video)
        #expect(video.count == 2)
        #expect(video.allSatisfy { $0.category == .video })
    }

    // MARK: - Bulk Operations

    @Test("saveAll then fetchAll returns all items")
    func saveAllAndFetchAll() throws {
        let (repo, _) = try makeRepo()
        let items = (0..<50).map { makeItem(title: "Item \($0)") }

        try repo.saveAll(items)
        let fetched = try repo.fetchAll()
        #expect(fetched.count == 50)
    }

    @Test("deleteAll wipes entire store")
    func deleteAll() throws {
        let (repo, _) = try makeRepo()
        try repo.saveAll((0..<10).map { makeItem(title: "Item \($0)") })
        try repo.deleteAll()

        let remaining = try repo.fetchAll()
        #expect(remaining.isEmpty)
    }

    @Test("saveAll with 0 items does not throw")
    func saveAllEmpty() throws {
        let (repo, _) = try makeRepo()
        #expect(throws: Never.self) {
            try repo.saveAll([])
        }
    }

    // MARK: - Data Integrity

    @Test("BillingCycle.custom roundtrips through persistence")
    func billingCycleCustomRoundtrip() throws {
        let (repo, _) = try makeRepo()
        var item = makeItem()
        item = RecurringItem(
            id: item.id, title: item.title, providerID: nil, providerName: item.providerName,
            itemType: item.itemType, category: item.category, amount: item.amount,
            currencyCode: item.currencyCode, billingCycle: .custom(days: 45),
            startDate: item.startDate, nextChargeDate: item.nextChargeDate,
            trialEndDate: nil, status: item.status, usageStatus: item.usageStatus,
            paymentMethodID: nil, note: "", tags: [], isShared: false, isFamilyPlan: false,
            bundleID: nil, managementURL: nil, createdAt: item.createdAt,
            updatedAt: item.updatedAt, archivedAt: nil
        )
        try repo.save(item)
        let fetched = try repo.fetch(id: item.id)

        if case .custom(let days) = fetched?.billingCycle {
            #expect(days == 45)
        } else {
            Issue.record("Expected .custom(days: 45), got \(String(describing: fetched?.billingCycle))")
        }
    }

    @Test("tags roundtrip through persistence unchanged")
    func tagsRoundtrip() throws {
        let (repo, _) = try makeRepo()
        let tags = ["annual", "family", "high-cost"]
        var item = makeItem()
        item = RecurringItem(
            id: item.id, title: item.title, providerID: nil, providerName: item.providerName,
            itemType: item.itemType, category: item.category, amount: item.amount,
            currencyCode: item.currencyCode, billingCycle: item.billingCycle,
            startDate: item.startDate, nextChargeDate: item.nextChargeDate,
            trialEndDate: nil, status: item.status, usageStatus: item.usageStatus,
            paymentMethodID: nil, note: "", tags: tags, isShared: false, isFamilyPlan: false,
            bundleID: nil, managementURL: nil, createdAt: item.createdAt,
            updatedAt: item.updatedAt, archivedAt: nil
        )
        try repo.save(item)
        let fetched = try repo.fetch(id: item.id)
        #expect(fetched?.tags == tags)
    }

    @Test("managementURL roundtrips as valid URL")
    func managementURLRoundtrip() throws {
        let (repo, _) = try makeRepo()
        let url = URL(string: "https://netflix.com/account")!
        var item = makeItem()
        item = RecurringItem(
            id: item.id, title: item.title, providerID: nil, providerName: item.providerName,
            itemType: item.itemType, category: item.category, amount: item.amount,
            currencyCode: item.currencyCode, billingCycle: item.billingCycle,
            startDate: item.startDate, nextChargeDate: item.nextChargeDate,
            trialEndDate: nil, status: item.status, usageStatus: item.usageStatus,
            paymentMethodID: nil, note: "", tags: [], isShared: false, isFamilyPlan: false,
            bundleID: nil, managementURL: url, createdAt: item.createdAt,
            updatedAt: item.updatedAt, archivedAt: nil
        )
        try repo.save(item)
        let fetched = try repo.fetch(id: item.id)
        #expect(fetched?.managementURL == url)
    }
}

// MARK: - Payment Method Repository Tests

@Suite("PaymentMethodRepository")
@MainActor
struct PaymentMethodRepositoryTests {

    private func makeRepo() throws -> SwiftDataPaymentMethodRepository {
        let container = try SorenModelContainer.inMemory()
        return SwiftDataPaymentMethodRepository(context: container.mainContext)
    }

    private func makeMethod(title: String = "Visa", isDefault: Bool = false) -> PaymentMethod {
        PaymentMethod(
            id: UUID(),
            title: title,
            type: .bankCard,
            maskedIdentifier: "••4242",
            isDefault: isDefault
        )
    }

    @Test("setDefault clears previous default")
    func setDefaultClearsPrevious() throws {
        let repo = try makeRepo()
        let first = makeMethod(title: "Visa", isDefault: true)
        let second = makeMethod(title: "Mastercard", isDefault: false)
        try repo.save(first)
        try repo.save(second)

        try repo.setDefault(id: second.id)

        let defaultMethod = try repo.fetchDefault()
        #expect(defaultMethod?.title == "Mastercard")

        let all = try repo.fetchAll()
        let defaults = all.filter(\.isDefault)
        #expect(defaults.count == 1)
    }

    @Test("setDefault on unknown ID throws notFound")
    func setDefaultUnknown() throws {
        let repo = try makeRepo()
        #expect(throws: RepositoryError.self) {
            try repo.setDefault(id: UUID())
        }
    }

    @Test("fetchDefault returns nil when no methods exist")
    func fetchDefaultEmpty() throws {
        let repo = try makeRepo()
        let result = try repo.fetchDefault()
        #expect(result == nil)
    }

    @Test("delete removes method from fetchAll")
    func deleteMethod() throws {
        let repo = try makeRepo()
        let method = makeMethod()
        try repo.save(method)
        try repo.delete(id: method.id)
        let all = try repo.fetchAll()
        #expect(all.isEmpty)
    }
}
