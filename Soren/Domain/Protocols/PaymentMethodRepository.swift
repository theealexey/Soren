import Foundation

@MainActor
protocol PaymentMethodRepository: AnyObject {
    func fetchAll() throws -> [PaymentMethod]
    func fetchDefault() throws -> PaymentMethod?
    func save(_ method: PaymentMethod) throws
    func delete(id: UUID) throws
    func setDefault(id: UUID) throws
}
