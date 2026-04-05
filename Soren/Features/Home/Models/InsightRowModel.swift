import Foundation

// MARK: - Insight Row Model

/// Data for one flat insight row below the landscape.
/// All strings pre-formatted by HomeViewModel.
struct InsightRowModel: Identifiable {

    // MARK: Row Identity

    /// Stable string keys — prevent spurious animations on data refresh.
    enum RowID: String { case peak, quiet, trial }
    let id: RowID

    // MARK: Content

    let label: String        // left column: "Peak week"
    let value: String        // right column: date range or name
    let amount: String?      // trailing amount; nil for quiet/trial rows

    // MARK: Visual Role

    /// Maps to a theme color token in the View layer.
    /// ViewModel never returns Color — only this semantic role.
    let valueRole: ValueRole

    enum ValueRole { case standard, warning, quiet }
}
