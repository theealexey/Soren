import Testing
import Foundation
import SwiftData
@testable import Soren

// MARK: - Add Subscription Tier Tests (Adversarial)

/// Tests tier selection logic in AddSubscriptionViewModel:
/// auto-select, manual pick, clear, provider switch, edge cases.

@Suite("AddSubscription — Tier Selection")
@MainActor
struct AddSubscriptionTierTests {

    private func makeViewModel() throws -> AddSubscriptionViewModel {
        let container = try SorenModelContainer.inMemory()
        let repo = SwiftDataRecurringItemRepository(context: container.mainContext)
        return AddSubscriptionViewModel(
            catalog: InMemoryProviderCatalogRepository(),
            saveRecurringItem: SaveRecurringItem(repository: repo)
        )
    }

    private func providerWithTiers(_ tiers: [PlanTier]) -> ProviderTemplate {
        ProviderTemplate(
            id: "test-provider",
            displayName: "Test Provider",
            category: .video,
            suggestedCycle: .monthly,
            suggestedCurrencyCode: "USD",
            plans: tiers
        )
    }

    private let singleTier = [
        PlanTier(id: "basic", name: "Basic", amount: 9.99, billingCycle: .monthly)
    ]

    private let multipleTiers = [
        PlanTier(id: "basic", name: "Basic", amount: 9.99, billingCycle: .monthly),
        PlanTier(id: "standard", name: "Standard", amount: 15.49, billingCycle: .monthly),
        PlanTier(id: "premium", name: "Premium", amount: 22.99, billingCycle: .monthly,
                 features: "4K HDR, 4 screens"),
    ]

    // MARK: - Auto-Select Single Tier

    @Test("Provider with 1 tier auto-selects it on selectProvider")
    func autoSelectSingleTier() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers(singleTier)

        vm.selectProvider(provider)

        #expect(vm.selectedTier?.id == "basic")
        #expect(vm.amountText == "9.99")
    }

    // MARK: - Multiple Tiers

    @Test("Provider with 3 tiers does not auto-select, clears amount")
    func multiTierNoAutoSelect() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers(multipleTiers)

        vm.selectProvider(provider)

        #expect(vm.selectedTier == nil)
        #expect(vm.amountText == "")
        #expect(vm.availableTiers.count == 3)
    }

    // MARK: - Zero Tiers

    @Test("Provider with 0 tiers has empty availableTiers, no crash")
    func zeroTiers() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers([])

        vm.selectProvider(provider)

        #expect(vm.availableTiers.isEmpty)
        #expect(vm.selectedTier == nil)
    }

    // MARK: - Select Tier

    @Test("selectTier fills amount, cycle, and currency override")
    func selectTierFillsFields() throws {
        let vm = try makeViewModel()
        let tier = PlanTier(
            id: "annual",
            name: "Annual",
            amount: 119.88,
            billingCycle: .annual,
            currencyCode: "EUR",
            features: "Save 20%"
        )
        let provider = providerWithTiers([tier,
            PlanTier(id: "monthly", name: "Monthly", amount: 12.99, billingCycle: .monthly)])

        vm.selectProvider(provider)
        vm.selectTier(tier)

        #expect(vm.selectedTier?.id == "annual")
        #expect(vm.amountText == "119.88")
        #expect(vm.billingCycle == .annual)
        #expect(vm.currencyCode == "EUR")
    }

    @Test("selectTier with nil currencyCode keeps provider's currency")
    func tierNilCurrencyKeepsProvider() throws {
        let vm = try makeViewModel()
        let tier = PlanTier(id: "basic", name: "Basic", amount: 9.99,
                            billingCycle: .monthly, currencyCode: nil)
        let provider = providerWithTiers([tier,
            PlanTier(id: "pro", name: "Pro", amount: 19.99, billingCycle: .monthly)])

        vm.selectProvider(provider)
        vm.selectTier(tier)

        #expect(vm.currencyCode == "USD", "Should keep provider's suggestedCurrencyCode")
    }

    // MARK: - Clear Tier

    @Test("clearTier resets to provider defaults")
    func clearTierResetsDefaults() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers(multipleTiers)

        vm.selectProvider(provider)
        vm.selectTier(multipleTiers[2]) // Premium

        #expect(vm.amountText == "22.99")

        vm.clearTier()

        #expect(vm.selectedTier == nil)
        #expect(vm.amountText == "")
        #expect(vm.billingCycle == .monthly, "Should reset to provider's suggested cycle")
        #expect(vm.currencyCode == "USD", "Should reset to provider's suggested currency")
    }

    // MARK: - Manual Entry

    @Test("startManualEntry clears both provider and tier")
    func manualEntryClearsBoth() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers(singleTier)

        vm.selectProvider(provider)
        #expect(vm.selectedTier != nil)
        #expect(vm.selectedProvider != nil)

        vm.startManualEntry()

        #expect(vm.selectedProvider == nil)
        #expect(vm.selectedTier == nil)
        #expect(vm.title == "")
        #expect(vm.amountText == "")
    }

    // MARK: - Switch Provider

    @Test("Switching provider clears previous tier")
    func switchProviderClearsTier() throws {
        let vm = try makeViewModel()
        let provider1 = providerWithTiers(singleTier)
        let provider2 = ProviderTemplate(
            id: "provider2",
            displayName: "Provider 2",
            category: .music,
            suggestedCurrencyCode: "RUB",
            plans: multipleTiers
        )

        vm.selectProvider(provider1)
        #expect(vm.selectedTier?.id == "basic") // auto-selected

        vm.selectProvider(provider2)
        #expect(vm.selectedTier == nil, "Previous tier should be cleared")
        #expect(vm.availableTiers.count == 3)
    }

    // MARK: - Cycle: Select → Clear → Reselect

    @Test("Select tier, clear, reselect — state is consistent")
    func selectClearReselect() throws {
        let vm = try makeViewModel()
        let provider = providerWithTiers(multipleTiers)

        vm.selectProvider(provider)

        // Select Premium
        vm.selectTier(multipleTiers[2])
        #expect(vm.amountText == "22.99")

        // Clear
        vm.clearTier()
        #expect(vm.amountText == "")
        #expect(vm.selectedTier == nil)

        // Reselect Basic
        vm.selectTier(multipleTiers[0])
        #expect(vm.amountText == "9.99")
        #expect(vm.selectedTier?.id == "basic")
    }

    // MARK: - availableTiers Computed Property

    @Test("availableTiers reflects selectedProvider's plans")
    func availableTiersReflectsProvider() throws {
        let vm = try makeViewModel()

        #expect(vm.availableTiers.isEmpty, "No provider selected → empty")

        vm.selectProvider(providerWithTiers(multipleTiers))
        #expect(vm.availableTiers.count == 3)

        vm.startManualEntry()
        #expect(vm.availableTiers.isEmpty, "Manual entry → no tiers")
    }
}
