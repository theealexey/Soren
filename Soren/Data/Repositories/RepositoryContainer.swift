import Foundation
import SwiftData

// MARK: - Repository Container

/// Single point of access for all repositories.
/// Created once at app launch, immutable after init.
/// Accessed through `AppContainer` which is injected into SwiftUI environment.
@MainActor
final class RepositoryContainer {

    let recurringItems: any RecurringItemRepository
    let paymentRecords: any PaymentRecordRepository
    let paymentMethods: any PaymentMethodRepository

    // MARK: - Init

    init(context: ModelContext) {
        self.recurringItems = SwiftDataRecurringItemRepository(context: context)
        self.paymentRecords = SwiftDataPaymentRecordRepository(context: context)
        self.paymentMethods = SwiftDataPaymentMethodRepository(context: context)
    }
}
