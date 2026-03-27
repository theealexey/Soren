import SwiftData
import Foundation

// MARK: - Soren Model Container

/// Central factory for the SwiftData ModelContainer.
/// All @Model types are registered here — this is the single source of truth
/// for the schema. New models must be added to `schema` below.
enum SorenModelContainer {

    // MARK: - Schema

    /// All persistent model types in declaration order.
    /// Order matters for schema migrations — do not rearrange arbitrarily.
    static let schema = Schema([
        SDRecurringItem.self,
        SDPaymentRecord.self,
        SDPaymentMethod.self,
        SDReminderRule.self,
    ])

    // MARK: - Production Container

    /// Production container: data persisted to disk.
    static func production() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - In-Memory Container (tests / previews)

    /// Ephemeral container: data exists only in memory.
    /// Use in tests and SwiftUI Previews to avoid polluting production store.
    static func inMemory() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: config)
    }
}
