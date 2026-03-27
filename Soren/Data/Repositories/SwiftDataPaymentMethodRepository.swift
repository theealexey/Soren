import Foundation
import SwiftData

// MARK: - SwiftData Repository: Payment Methods

@MainActor
final class SwiftDataPaymentMethodRepository: PaymentMethodRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [PaymentMethod] {
        let descriptor = FetchDescriptor<SDPaymentMethod>(
            sortBy: [SortDescriptor(\.title)]
        )
        return try context.fetch(descriptor).map(PaymentMethodMapper.toDomain)
    }

    func fetchDefault() throws -> PaymentMethod? {
        let descriptor = FetchDescriptor<SDPaymentMethod>(
            predicate: #Predicate { method in method.isDefault }
        )
        return try context.fetch(descriptor).first.map(PaymentMethodMapper.toDomain)
    }

    func save(_ method: PaymentMethod) throws {
        let sd = PaymentMethodMapper.toSD(method)
        context.insert(sd)
        try context.save()
    }

    func delete(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<SDPaymentMethod>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else { return }
        context.delete(sd)
        try context.save()
    }

    func setDefault(id: UUID) throws {
        // Clear existing default
        let allDescriptor = FetchDescriptor<SDPaymentMethod>()
        let all = try context.fetch(allDescriptor)
        all.forEach { $0.isDefault = false }

        // Set new default
        guard let target = all.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound(id)
        }
        target.isDefault = true
        try context.save()
    }
}
