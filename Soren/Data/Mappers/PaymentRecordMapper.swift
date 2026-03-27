import Foundation

enum PaymentRecordMapper {

    static func toDomain(_ sd: SDPaymentRecord, itemID: UUID) -> PaymentRecord {
        PaymentRecord(
            id: sd.id,
            recurringItemID: itemID,
            amount: sd.amountValue,
            currencyCode: sd.currencyCode,
            paymentDate: sd.paymentDate,
            status: PaymentRecord.Status(rawValue: sd.statusRaw) ?? .manual,
            paymentMethodID: sd.paymentMethodID,
            note: sd.note
        )
    }

    static func toSD(_ domain: PaymentRecord) -> SDPaymentRecord {
        SDPaymentRecord(
            id: domain.id,
            amountValue: domain.amount,
            currencyCode: domain.currencyCode,
            paymentDate: domain.paymentDate,
            statusRaw: domain.status.rawValue,
            paymentMethodID: domain.paymentMethodID,
            note: domain.note
        )
    }
}
