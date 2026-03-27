import SwiftData
import Foundation

/// Persistent storage model for a single payment charge event.
@Model
final class SDPaymentRecord {

    @Attribute(.unique) var id: UUID
    var itemID: UUID            // denormalized for fast predicate filtering
    var amountValue: Decimal
    var currencyCode: String
    var paymentDate: Date
    var statusRaw: String
    var paymentMethodID: UUID?
    var note: String

    // MARK: - Relationship

    var item: SDRecurringItem?

    // MARK: - Init

    init(
        id: UUID,
        itemID: UUID,
        amountValue: Decimal,
        currencyCode: String,
        paymentDate: Date,
        statusRaw: String,
        paymentMethodID: UUID?,
        note: String
    ) {
        self.id = id
        self.itemID = itemID
        self.amountValue = amountValue
        self.currencyCode = currencyCode
        self.paymentDate = paymentDate
        self.statusRaw = statusRaw
        self.paymentMethodID = paymentMethodID
        self.note = note
    }
}
