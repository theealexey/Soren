import Foundation
import SwiftData

/// Persists an explicit migration interpretation policy, not proven historical provenance.
/// Production startup adoption belongs to 4B2A2B-2.
@MainActor
struct LegacyBillingDateProvenanceBootstrap {
    private let save: @MainActor (ModelContext) throws -> Void

    /// The save seam permits batch/no-op/failure verification without a repository abstraction.
    init(save: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }) {
        self.save = save
    }

    @discardableResult
    func execute(container: ModelContainer, interpretationTimeZone: TimeZone) throws -> Int {
        let identifier = interpretationTimeZone.identifier
        guard TimeZone(identifier: identifier) != nil else {
            throw RecurringItemBillingDateAdapterError.invalidSuppliedTimeZoneIdentifier(identifier)
        }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        let rows = try context.fetch(FetchDescriptor<SDRecurringItem>())
        let candidates = rows.filter {
            $0.billingDateEncodingVersion == nil
                && $0.legacyBillingDateInterpretationTimeZoneIdentifier == nil
        }
        guard !candidates.isEmpty else { return 0 }

        for row in candidates {
            row.legacyBillingDateInterpretationTimeZoneIdentifier = identifier
        }
        do {
            try save(context)
        } catch {
            context.rollback()
            throw error
        }
        return candidates.count
    }
}
