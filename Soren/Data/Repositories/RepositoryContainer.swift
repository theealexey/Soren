import Foundation
import SwiftData

// MARK: - Repository Container

/// Single point of access for all repositories.
/// Passed into the SwiftUI environment from the App entry point.
///
/// Usage:
///     @Environment(RepositoryContainer.self) var repos
///     let items = try await repos.recurringItems.fetchAll()
@MainActor
final class RepositoryContainer: ObservableObject {

    let recurringItems: any RecurringItemRepository
    let paymentRecords: any PaymentRecordRepository
    let paymentMethods: any PaymentMethodRepository

    // MARK: - Init

    init(
        recurringItems: any RecurringItemRepository,
        paymentRecords: any PaymentRecordRepository,
        paymentMethods: any PaymentMethodRepository
    ) {
        self.recurringItems = recurringItems
        self.paymentRecords = paymentRecords
        self.paymentMethods = paymentMethods
    }

    // MARK: - Factory: Production

    convenience init(context: ModelContext) {
        self.init(
            recurringItems: SwiftDataRecurringItemRepository(context: context),
            paymentRecords: SwiftDataPaymentRecordRepository(context: context),
            paymentMethods: SwiftDataPaymentMethodRepository(context: context)
        )
    }
}
