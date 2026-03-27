import Foundation

protocol PaymentRecordRepository: Sendable {
    func fetchAll(for itemID: UUID) async throws -> [PaymentRecord]
    func save(_ record: PaymentRecord) async throws
    func delete(id: UUID) async throws
}
