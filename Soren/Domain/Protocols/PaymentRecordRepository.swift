import Foundation

@MainActor
protocol PaymentRecordRepository: AnyObject {
    func fetchAll(for itemID: UUID) throws -> [PaymentRecord]
    func save(_ record: PaymentRecord) throws
    func delete(id: UUID) throws
}
