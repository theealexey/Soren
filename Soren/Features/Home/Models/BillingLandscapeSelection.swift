import Foundation

// MARK: - Billing Landscape Selection

/// Stable selection keyed by Date, not array index.
/// Built by HomeViewModel when the user taps or scrubs to a day.
struct BillingLandscapeSelection: Equatable {

    /// Canonical calendar day (start-of-day). Used for bar matching.
    let date: Date

    /// Pre-formatted by ViewModel. e.g. "Apr 9"
    let formattedDate: String

    let charges: [ChargeLineItem]

    /// Pre-formatted total for this day. e.g. "₽1 249"
    let totalFormatted: String

    // MARK: - Charge Line Item

    struct ChargeLineItem: Identifiable, Equatable {
        let id: UUID
        let name: String
        let amountFormatted: String
    }
}
