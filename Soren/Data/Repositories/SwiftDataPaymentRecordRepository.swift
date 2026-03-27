import Foundation
import SwiftData

// MARK: - SwiftData Repository: Payment Records

@MainActor
final class SwiftDataPaymentRecordRepository: PaymentRecordRepository {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll(for itemID: UUID) throws -> [PaymentRecord] {
        let targetID = itemID
        let descriptor = FetchDescriptor<SDPaymentRecord>(
            predicate: #Predicate { record in record.itemID == targetID },
            sortBy: [SortDescriptor(\.paymentDate, order: .reverse)]
        )
        return try context.fetch(descriptor).map(PaymentRecordMapper.toDomain)
    }

    func save(_ record: PaymentRecord) throws {
        let sd = PaymentRecordMapper.toSD(record)
        context.insert(sd)
        try context.save()
    }

    func delete(id: UUID) throws {
        let targetID = id
        let descriptor = FetchDescriptor<SDPaymentRecord>(
            predicate: #Predicate { sd in sd.id == targetID }
        )
        guard let sd = try context.fetch(descriptor).first else { return }
        context.delete(sd)
        try context.save()
    }
}
