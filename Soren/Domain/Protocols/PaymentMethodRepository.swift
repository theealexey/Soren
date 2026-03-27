import Foundation

protocol PaymentMethodRepository: Sendable {
    func fetchAll() async throws -> [PaymentMethod]
    func fetchDefault() async throws -> PaymentMethod?
    func save(_ method: PaymentMethod) async throws
    func delete(id: UUID) async throws
    func setDefault(id: UUID) async throws
}
