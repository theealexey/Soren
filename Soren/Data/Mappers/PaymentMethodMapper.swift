import Foundation

enum PaymentMethodMapper {

    static func toDomain(_ sd: SDPaymentMethod) -> PaymentMethod {
        PaymentMethod(
            id: sd.id,
            title: sd.title,
            type: PaymentMethodType(rawValue: sd.typeRaw) ?? .unknown,
            maskedIdentifier: sd.maskedIdentifier,
            isDefault: sd.isDefault
        )
    }

    static func toSD(_ domain: PaymentMethod) -> SDPaymentMethod {
        SDPaymentMethod(
            id: domain.id,
            title: domain.title,
            typeRaw: domain.type.rawValue,
            maskedIdentifier: domain.maskedIdentifier,
            isDefault: domain.isDefault
        )
    }

    static func update(_ sd: SDPaymentMethod, from domain: PaymentMethod) {
        sd.title = domain.title
        sd.typeRaw = domain.type.rawValue
        sd.maskedIdentifier = domain.maskedIdentifier
        sd.isDefault = domain.isDefault
    }
}
