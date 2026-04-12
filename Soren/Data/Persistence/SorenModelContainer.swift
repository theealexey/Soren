import SwiftData
import Foundation

// MARK: - Soren Model Container

/// Central factory for the SwiftData ModelContainer.
/// Model types are declared in SorenSchemaVersions.swift.
/// To add a new model: (1) create SorenSchemaV2 in SorenSchemaVersions.swift,
/// (2) add a MigrationStage to SorenMigrationPlan.stages,
/// (3) update `currentSchema` below.
enum SorenModelContainer {

    // MARK: - Schema

    /// Derived from the current versioned schema — do not list models here directly.
    static let schema = Schema(SorenSchemaV1.models)

    // MARK: - Production Container

    /// Production container: data persisted to disk.
    /// Uses ModelContainer(for:) to remain compatible with stores created before
    /// migration-plan metadata was introduced. Re-introduce ModelContainer(migrationPlan:)
    /// when SorenSchemaV2 is defined and all on-device stores have been opened at
    /// least once under this build.
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

    // MARK: - Recovery

    /// Deletes the production SQLite store and its WAL/SHM sidecar files.
    /// Called when the store is corrupted (e.g., failed iCloud sync).
    /// After calling this, re-invoke `production()` for a fresh empty store.
    static func deleteProductionStore() {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        let base = config.url
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = suffix.isEmpty ? base : URL(fileURLWithPath: base.path + suffix)
            try? fm.removeItem(at: url)
        }
    }
}
