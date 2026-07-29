import Testing
import SwiftData
@testable import Soren

@MainActor
struct InMemoryPersistenceFixture {
    let modelContainer: ModelContainer
    let repositories: RepositoryContainer
    let recurringItems: SwiftDataRecurringItemRepository
    let paymentMethods: SwiftDataPaymentMethodRepository

    init() throws {
        let modelContainer = try SorenModelContainer.inMemory()
        let context = modelContainer.mainContext

        self.modelContainer = modelContainer
        self.repositories = RepositoryContainer(context: context)
        self.recurringItems = SwiftDataRecurringItemRepository(context: context)
        self.paymentMethods = SwiftDataPaymentMethodRepository(context: context)
    }
}

@Suite("Soren Core Tests")
struct SorenCoreTests {
    @Test("App launches successfully")
    func appExists() {
        // Placeholder — will be replaced with real tests as we build features
        #expect(true)
    }
}
