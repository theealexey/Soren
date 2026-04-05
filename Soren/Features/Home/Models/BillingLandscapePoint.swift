import Foundation

// MARK: - Billing Landscape Point

/// One calendar day's billing weight within the 30-day landscape.
/// `id` is the day offset (0-based) — stable within a displayed month,
/// enabling predictable SwiftUI diffing across data reloads.
struct BillingLandscapePoint: Identifiable {

    /// Day offset from the start of the displayed window. 0 = today.
    let id: Int

    let date: Date

    /// 0.0–1.0. Derived: rawTotal / maxDayTotal in the window.
    /// Exactly 0.0 for zero-charge days.
    let normalizedHeight: Double

    let rawTotal: Decimal
    let currencyCode: String
    let chargeCount: Int
}
