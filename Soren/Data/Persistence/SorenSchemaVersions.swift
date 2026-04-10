import SwiftData

// MARK: - Schema Versions

/// Version history for the Soren SwiftData schema.
///
/// Each new model version must be added here as a new `VersionedSchema` type,
/// with a corresponding `MigrationStage` entry in `SorenMigrationPlan.stages`.
///
/// For additive changes (new optional property, new model type), a lightweight
/// migration stage is sufficient. For structural changes (required field removal,
/// type change, relationship removal), a custom migration stage is required.
enum SorenSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SDRecurringItem.self,
            SDPaymentRecord.self,
            SDPaymentMethod.self,
            SDReminderRule.self,
        ]
    }
}

// MARK: - Migration Plan

/// Declares the full ordered history of schema versions.
/// SwiftData uses this to determine which migration stages to run when
/// opening an existing store that was created at an earlier version.
enum SorenMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SorenSchemaV1.self]
    }

    /// No migrations yet — only one version exists.
    /// Add a MigrationStage here when introducing SorenSchemaV2.
    static var stages: [MigrationStage] { [] }
}
