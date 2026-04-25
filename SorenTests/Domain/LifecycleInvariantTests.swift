import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Lifecycle Invariant Tests
//
// Covers:
//  1. Valid state matrix (all legal combinations accepted)
//  2. R1 — reject autoRenew=false && endDate=nil
//  3. R2 — reject autoRenew=false && endDate < nextChargeDate
//  4. R3 — reject endDate != nil && startDate > endDate
//  5. Write-time normalization: autoRenew=true clears endDate before persistence
//  6. Migration defaults: SDRecurringItem with nil autoRenew maps to domain autoRenew=true

@Suite("RecurringItem — Lifecycle Invariants")
@MainActor
struct LifecycleInvariantTests {

    // MARK: - Helpers

    private func makeSaveUseCase() throws -> (SaveRecurringItem, SwiftDataRecurringItemRepository) {
        let container = try SorenModelContainer.inMemory()
        let repo = SwiftDataRecurringItemRepository(context: container.mainContext)
        return (SaveRecurringItem(repository: repo), repo)
    }

    private func makeUpdateUseCase() throws -> (UpdateRecurringItem, SwiftDataRecurringItemRepository) {
        let container = try SorenModelContainer.inMemory()
        let repo = SwiftDataRecurringItemRepository(context: container.mainContext)
        return (UpdateRecurringItem(repository: repo), repo)
    }

    /// Builds a baseline valid item. Dates are fixed reference points for clarity.
    private func makeItem(
        autoRenew: Bool = true,
        startDate: Date = .distantPast,
        nextChargeDate: Date,
        endDate: Date? = nil
    ) -> RecurringItem {
        RecurringItem(
            title: "Test Sub",
            amount: 9.99,
            startDate: startDate,
            nextChargeDate: nextChargeDate,
            autoRenew: autoRenew,
            endDate: endDate
        )
    }

    // MARK: - 1. Valid State Matrix

    @Test("Valid: autoRenew=true, endDate=nil — the default, indefinite case")
    func validAutoRenewNoEndDate() throws {
        let (uc, _) = try makeSaveUseCase()
        let item = makeItem(autoRenew: true, nextChargeDate: .now, endDate: nil)
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    @Test("Valid: autoRenew=false with endDate after nextChargeDate")
    func validFiniteWithEndDateAfterNextCharge() throws {
        let (uc, _) = try makeSaveUseCase()
        let next  = Date.now
        let end   = Calendar.current.date(byAdding: .day, value: 30, to: next)!
        let item  = makeItem(autoRenew: false, nextChargeDate: next, endDate: end)
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    @Test("Valid: autoRenew=false with endDate == nextChargeDate (final charge on end date)")
    func validFiniteEndDateEqualsNextCharge() throws {
        let (uc, _) = try makeSaveUseCase()
        let date = Date.now
        let item = makeItem(autoRenew: false, nextChargeDate: date, endDate: date)
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    @Test("Valid: autoRenew=true with stale endDate — normalization clears it, accepted")
    func validAutoRenewWithStaleEndDateAcceptedAfterNormalization() throws {
        let (uc, _) = try makeSaveUseCase()
        // Caller passes endDate even though autoRenew=true; normalization clears it.
        let item = makeItem(autoRenew: true, nextChargeDate: .now,
                            endDate: Calendar.current.date(byAdding: .day, value: 10, to: .now))
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    // MARK: - 2. R1: autoRenew=false && endDate=nil

    @Test("R1 Save: finite subscription without endDate is rejected")
    func r1SaveRejectsFiniteWithNoEndDate() throws {
        let (uc, _) = try makeSaveUseCase()
        let item = makeItem(autoRenew: false, nextChargeDate: .now, endDate: nil)
        #expect(throws: SaveRecurringItem.ValidationError.missingEndDate) {
            try uc.execute(item)
        }
    }

    @Test("R1 Update: finite subscription without endDate is rejected")
    func r1UpdateRejectsFiniteWithNoEndDate() async throws {
        let (uc, _) = try makeUpdateUseCase()
        let item = makeItem(autoRenew: false, nextChargeDate: .now, endDate: nil)
        await #expect(throws: UpdateRecurringItem.ValidationError.missingEndDate) {
            try await uc.execute(item)
        }
    }

    // MARK: - 3. R2: endDate < nextChargeDate

    @Test("R2 Save: endDate one day before nextChargeDate is rejected")
    func r2SaveRejectsEndDateBeforeNextCharge() throws {
        let (uc, _) = try makeSaveUseCase()
        let next = Date.now
        let end  = Calendar.current.date(byAdding: .day, value: -1, to: next)!
        let item = makeItem(autoRenew: false, nextChargeDate: next, endDate: end)
        #expect(throws: SaveRecurringItem.ValidationError.endDateBeforeNextCharge) {
            try uc.execute(item)
        }
    }

    @Test("R2 Update: endDate one day before nextChargeDate is rejected")
    func r2UpdateRejectsEndDateBeforeNextCharge() async throws {
        let (uc, _) = try makeUpdateUseCase()
        let next = Date.now
        let end  = Calendar.current.date(byAdding: .day, value: -1, to: next)!
        let item = makeItem(autoRenew: false, nextChargeDate: next, endDate: end)
        await #expect(throws: UpdateRecurringItem.ValidationError.endDateBeforeNextCharge) {
            try await uc.execute(item)
        }
    }

    @Test("R2 boundary: endDate == nextChargeDate is NOT rejected")
    func r2BoundaryEndDateEqualNextChargeAccepted() throws {
        let (uc, _) = try makeSaveUseCase()
        let date = Date.now
        let item = makeItem(autoRenew: false, nextChargeDate: date, endDate: date)
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    // MARK: - 4. R3: startDate > endDate

    @Test("R3 Save: startDate one day after endDate is rejected")
    func r3SaveRejectsStartDateAfterEndDate() throws {
        let (uc, _) = try makeSaveUseCase()
        let next  = Date.now
        let end   = Calendar.current.date(byAdding: .day, value: 30, to: next)!
        let start = Calendar.current.date(byAdding: .day, value: 31, to: next)!   // start > end
        let item  = makeItem(autoRenew: false, startDate: start, nextChargeDate: next, endDate: end)
        #expect(throws: SaveRecurringItem.ValidationError.startDateAfterEndDate) {
            try uc.execute(item)
        }
    }

    @Test("R3 Update: startDate one day after endDate is rejected")
    func r3UpdateRejectsStartDateAfterEndDate() async throws {
        let (uc, _) = try makeUpdateUseCase()
        let next  = Date.now
        let end   = Calendar.current.date(byAdding: .day, value: 30, to: next)!
        let start = Calendar.current.date(byAdding: .day, value: 31, to: next)!
        let item  = makeItem(autoRenew: false, startDate: start, nextChargeDate: next, endDate: end)
        await #expect(throws: UpdateRecurringItem.ValidationError.startDateAfterEndDate) {
            try await uc.execute(item)
        }
    }

    @Test("R3 boundary: startDate == endDate is NOT rejected")
    func r3BoundaryStartEqualsEndAccepted() throws {
        let (uc, _) = try makeSaveUseCase()
        let next = Date.now
        let end  = Calendar.current.date(byAdding: .day, value: 1, to: next)!
        // Use same date for start and end — not rejected by R3 (strict >)
        let item = makeItem(autoRenew: false, startDate: end, nextChargeDate: next, endDate: end)
        #expect(throws: Never.self) { try uc.execute(item) }
    }

    // MARK: - 5. Write-time normalization

    @Test("Normalization: autoRenew=true clears endDate before persistence (Save)")
    func normalizationClearsEndDateOnSave() throws {
        let (uc, repo) = try makeSaveUseCase()
        let staleEnd = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let item = makeItem(autoRenew: true, nextChargeDate: .now, endDate: staleEnd)

        try uc.execute(item)

        let saved = try repo.fetchAll().first
        #expect(saved != nil)
        #expect(saved?.autoRenew == true)
        #expect(saved?.endDate == nil)   // must have been cleared, not persisted
    }

    @Test("Normalization: autoRenew=true clears endDate before persistence (Update)")
    func normalizationClearsEndDateOnUpdate() async throws {
        // Inline container setup keeps it alive through the async suspension in execute().
        let seedContainer = try SorenModelContainer.inMemory()
        let seedRepo      = SwiftDataRecurringItemRepository(context: seedContainer.mainContext)

        let end  = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        var item = makeItem(autoRenew: false, nextChargeDate: .now, endDate: end)

        // Persist the finite item first so the update use case can find and mutate it.
        let saveUC = SaveRecurringItem(repository: seedRepo)
        try saveUC.execute(item)

        // Now re-enable auto-renew (with stale endDate still set on struct).
        item.autoRenew = true   // endDate still non-nil on the struct at this point
        let updateUC = UpdateRecurringItem(repository: seedRepo)
        let result = try await updateUC.execute(item)

        #expect(result.autoRenew == true)
        #expect(result.endDate == nil)   // normalization must have cleared it
    }

    @Test("Normalization: autoRenew=false preserves endDate unchanged")
    func normalizationPreservesEndDateForFiniteSubscription() throws {
        let (uc, repo) = try makeSaveUseCase()
        let end  = Calendar.current.date(byAdding: .day, value: 60, to: .now)!
        let item = makeItem(autoRenew: false, nextChargeDate: .now, endDate: end)

        try uc.execute(item)

        let saved = try repo.fetchAll().first
        #expect(saved?.autoRenew == false)
        #expect(saved?.endDate == end)
    }

    // MARK: - 6. Migration defaults (mapper with nil autoRenew)

    @Test("Mapper: SDRecurringItem with nil autoRenew maps to domain autoRenew=true")
    func mapperNilAutoRenewDefaultsToTrue() throws {
        let container = try SorenModelContainer.inMemory()
        let context   = ModelContext(container)

        // Simulate a legacy row: autoRenew not set (nil), as migration produces
        let sd = SDRecurringItem(
            id: UUID(),
            title: "Legacy Sub",
            providerID: nil,
            providerName: "Legacy",
            itemTypeRaw: ItemType.subscription.rawValue,
            categoryRaw: ItemCategory.other.rawValue,
            amountValue: 9.99,
            currencyCode: "USD",
            billingCycleRaw: "monthly",
            startDate: .now,
            nextChargeDate: .now,
            trialEndDate: nil,
            autoRenew: nil,       // ← legacy: no value in store
            endDate: nil,
            statusRaw: ItemStatus.active.rawValue,
            usageStatusRaw: UsageStatus.unknown.rawValue,
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
        context.insert(sd)

        let domain = RecurringItemMapper.toDomain(sd)

        #expect(domain.autoRenew == true)   // nil → true (safe legacy default)
        #expect(domain.endDate == nil)
    }

    @Test("Mapper: SDRecurringItem with explicit autoRenew=false and endDate preserved")
    func mapperExplicitFalseAutoRenewPreserved() throws {
        let container = try SorenModelContainer.inMemory()
        let context   = ModelContext(container)

        let end = Calendar.current.date(byAdding: .day, value: 30, to: .now)!
        let sd  = SDRecurringItem(
            id: UUID(),
            title: "Finite Sub",
            providerID: nil,
            providerName: "Finite",
            itemTypeRaw: ItemType.subscription.rawValue,
            categoryRaw: ItemCategory.other.rawValue,
            amountValue: 9.99,
            currencyCode: "USD",
            billingCycleRaw: "monthly",
            startDate: .now,
            nextChargeDate: .now,
            trialEndDate: nil,
            autoRenew: false,
            endDate: end,
            statusRaw: ItemStatus.active.rawValue,
            usageStatusRaw: UsageStatus.unknown.rawValue,
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
        context.insert(sd)

        let domain = RecurringItemMapper.toDomain(sd)

        #expect(domain.autoRenew == false)
        #expect(domain.endDate == end)
    }

    @Test("Round-trip: autoRenew and endDate survive toSD → toDomain")
    func roundTripAutoRenewEndDate() throws {
        let container = try SorenModelContainer.inMemory()
        let context   = ModelContext(container)

        let end      = Calendar.current.date(byAdding: .day, value: 45, to: .now)!
        let original = RecurringItem(
            title: "Finite",
            amount: 12.99,
            nextChargeDate: .now,
            autoRenew: false,
            endDate: end
        )

        let sd       = RecurringItemMapper.toSD(original)
        context.insert(sd)
        let restored = RecurringItemMapper.toDomain(sd)

        #expect(restored.autoRenew == false)
        #expect(restored.endDate == end)
    }
}
