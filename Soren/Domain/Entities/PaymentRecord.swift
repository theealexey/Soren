import Foundation

/// A single charge event for a recurring item.
/// Tracks both auto-detected and manually logged payments.
struct PaymentRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let recurringItemID: UUID
    var amount: Decimal
    var currencyCode: String
    var paymentDate: Date
    var status: Status
    var paymentMethodID: UUID?
    var note: String

    init(
        id: UUID = UUID(),
        recurringItemID: UUID,
        amount: Decimal,
        currencyCode: String = "RUB",
        paymentDate: Date = .now,
        status: Status = .success,
        paymentMethodID: UUID? = nil,
        note: String = ""
    ) {
        self.id = id
        self.recurringItemID = recurringItemID
        self.amount = amount
        self.currencyCode = currencyCode
        self.paymentDate = paymentDate
        self.status = status
        self.paymentMethodID = paymentMethodID
        self.note = note
    }
}

extension PaymentRecord {
    enum Status: String, Codable, CaseIterable, Sendable {
        case planned   // scheduled but not yet charged
        case success
        case failed
        case skipped   // user skipped this period
        case refunded
        case manual    // logged by user without auto-detection
    }
}
