import UIKit

// MARK: - Haptic Engine

/// Centralized haptic feedback with semantic naming.
/// Maps app actions to appropriate feedback intensity.
/// All methods are @MainActor since UIKit feedback generators require main thread.
@MainActor
enum HapticEngine {

    // MARK: - Retained generators (Apple recommends keeping these alive and calling prepare() before use)

    private static let notificationGen  = UINotificationFeedbackGenerator()
    private static let selectionGen     = UISelectionFeedbackGenerator()
    private static let lightImpactGen   = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGen  = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGen   = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Transactional

    /// Item added, payment marked as done, reminder saved.
    static func success() {
        notificationGen.notificationOccurred(.success)
    }

    /// Validation error, failed action.
    static func error() {
        notificationGen.notificationOccurred(.error)
    }

    /// Trial ending soon, upcoming charge alert.
    static func warning() {
        notificationGen.notificationOccurred(.warning)
    }

    // MARK: - Interactive

    /// Tab selection, filter toggle, chip tap.
    static func selection() {
        selectionGen.selectionChanged()
    }

    /// Button press, card tap.
    static func lightImpact() {
        lightImpactGen.impactOccurred()
    }

    /// Delete, archive action confirmation.
    static func mediumImpact() {
        mediumImpactGen.impactOccurred()
    }

    /// Destructive confirmation, pull-to-refresh threshold.
    static func heavyImpact() {
        heavyImpactGen.impactOccurred()
    }
}
