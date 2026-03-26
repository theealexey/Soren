import UIKit

// MARK: - Haptic Engine

/// Centralized haptic feedback with semantic naming.
/// Maps app actions to appropriate feedback intensity.
/// All methods are @MainActor since UIKit feedback generators require main thread.
@MainActor
enum HapticEngine {

    // MARK: - Transactional

    /// Item added, payment marked as done, reminder saved.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Validation error, failed action.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    /// Trial ending soon, upcoming charge alert.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    // MARK: - Interactive

    /// Tab selection, filter toggle, chip tap.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Button press, card tap.
    static func lightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Delete, archive action confirmation.
    static func mediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// Destructive confirmation, pull-to-refresh threshold.
    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
