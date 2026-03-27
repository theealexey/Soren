import Foundation

/// A bundle groups a primary item with included benefits.
/// Used for Яндекс Плюс (includes Кинопоиск + Музыка), СберПрайм+, etc.
///
/// Key insight: many ecosystem bundles make separate subscriptions redundant.
/// The Bundle entity powers overlap detection in Analytics.
struct ItemBundle: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String

    /// The master item (e.g. "Яндекс Плюс").
    var primaryItemID: UUID

    /// IDs of items that are included/covered by this bundle.
    /// If a user also pays for one of these separately, that's a duplicate.
    var includedBenefitIDs: [UUID]

    /// Free-text description of what's included.
    var note: String

    init(
        id: UUID = UUID(),
        title: String,
        primaryItemID: UUID,
        includedBenefitIDs: [UUID] = [],
        note: String = ""
    ) {
        self.id = id
        self.title = title
        self.primaryItemID = primaryItemID
        self.includedBenefitIDs = includedBenefitIDs
        self.note = note
    }
}
