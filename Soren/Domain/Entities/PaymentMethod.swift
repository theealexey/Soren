import Foundation

/// A stored payment method associated with one or more recurring items.
struct PaymentMethod: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var type: PaymentMethodType
    /// Last 4 digits of a card, or masked phone number, etc.
    var maskedIdentifier: String?
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        title: String,
        type: PaymentMethodType,
        maskedIdentifier: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.maskedIdentifier = maskedIdentifier
        self.isDefault = isDefault
    }
}

extension PaymentMethod {
    var displayTitle: String {
        guard let masked = maskedIdentifier, !masked.isEmpty else { return title }
        return "\(title) •••• \(masked)"
    }
}
