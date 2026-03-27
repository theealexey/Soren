import SwiftData
import Foundation

/// Persistent storage model for a payment method.
@Model
final class SDPaymentMethod {

    @Attribute(.unique) var id: UUID
    var title: String
    var typeRaw: String
    var maskedIdentifier: String?
    var isDefault: Bool

    init(
        id: UUID,
        title: String,
        typeRaw: String,
        maskedIdentifier: String?,
        isDefault: Bool
    ) {
        self.id = id
        self.title = title
        self.typeRaw = typeRaw
        self.maskedIdentifier = maskedIdentifier
        self.isDefault = isDefault
    }
}
