import Foundation

// MARK: - Next Payment Callout State

/// Drives the inline callout block below the Billing Landscape.
/// All strings are pre-formatted by HomeViewModel.
enum NextPaymentCalloutState: Equatable {

    /// Default: the next upcoming payment across all subscriptions.
    case nextPayment(
        countdown: String,        // "In 3 days" / "Tomorrow" / "Today"
        name: String,             // service name
        amountFormatted: String,
        additionalCount: Int      // 0 = hide "+N more" line
    )

    /// User has tapped or scrubbed to a day that has charges.
    case selectedDay(BillingLandscapeSelection)

    /// User has tapped a zero-charge day.
    case emptyDay(formattedDate: String)

    /// No upcoming charges exist in the 30-day window.
    case noUpcoming
}
