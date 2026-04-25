import Foundation

// MARK: - Repository Error

/// Errors that can be thrown by any repository.
/// Callers translate these into user-facing messages in the feature layer.
enum RepositoryError: Error, CustomDebugStringConvertible, Sendable {

    case notFound(UUID)
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case invalidData(String)

    var debugDescription: String {
        switch self {
        case .notFound(let id):
            "Item with ID \(id) was not found."
        case .saveFailed(let error):
            "Save failed: \(error.localizedDescription)"
        case .deleteFailed(let error):
            "Delete failed: \(error.localizedDescription)"
        case .invalidData(let reason):
            "Invalid data: \(reason)"
        }
    }
}
