import SwiftUI

// MARK: - Motion Tokens

/// Consistent animation curves and durations.
/// Premium = smooth and deliberate, never frantic.
enum MotionTokens {

    // MARK: - Durations

    /// Fast micro-interactions: toggle, selection highlight.
    static let fast: Double = 0.15

    /// Standard transitions: card expand, sheet present.
    static let standard: Double = 0.25

    /// Deliberate transitions: screen change, onboarding.
    static let slow: Double = 0.4

    // MARK: - Animations

    /// Snappy response for taps, toggles.
    static let snappy = Animation.snappy(duration: fast)

    /// Smooth default for most transitions.
    static let smooth = Animation.smooth(duration: standard)

    /// Gentle spring for sheets, modals, expanding cards.
    static let spring = Animation.spring(duration: standard, bounce: 0.2)

    /// Slow entrance for hero elements, onboarding.
    static let entrance = Animation.easeOut(duration: slow)
}
