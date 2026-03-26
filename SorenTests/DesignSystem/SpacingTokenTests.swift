import Testing
import CoreGraphics
@testable import Soren

@Suite("Design Tokens — Spacing & Corner Radius")
struct SpacingTokenTests {

    // MARK: - Spacing values must be on 4pt grid (except xxxs=2)

    @Test("All spacing values are positive")
    func allPositive() {
        let values = [Spacing.xxxs, Spacing.xxs, Spacing.xs, Spacing.sm,
                      Spacing.md, Spacing.lg, Spacing.xl, Spacing.xxl, Spacing.xxxl]
        for value in values {
            #expect(value > 0, "Spacing value must be positive, got \(value)")
        }
    }

    @Test("Spacing scale is monotonically increasing")
    func monotonicallyIncreasing() {
        let values = [Spacing.xxxs, Spacing.xxs, Spacing.xs, Spacing.sm,
                      Spacing.md, Spacing.lg, Spacing.xl, Spacing.xxl, Spacing.xxxl]
        for i in 1..<values.count {
            #expect(values[i] > values[i - 1],
                    "Spacing[\(i)] (\(values[i])) must be > Spacing[\(i-1)] (\(values[i-1]))")
        }
    }

    @Test("Core spacing values align to 4pt grid", arguments: [
        Spacing.xxs, Spacing.xs, Spacing.sm, Spacing.md,
        Spacing.lg, Spacing.xl, Spacing.xxl, Spacing.xxxl
    ])
    func fourPointGrid(value: CGFloat) {
        let remainder = value.truncatingRemainder(dividingBy: 4)
        #expect(remainder == 0, "\(value) is not on the 4pt grid")
    }

    // MARK: - Corner radius

    @Test("All corner radii are positive")
    func cornerRadiiPositive() {
        let values = [CornerRadius.small, CornerRadius.medium, CornerRadius.large, CornerRadius.extraLarge]
        for value in values {
            #expect(value > 0, "Corner radius must be positive, got \(value)")
        }
    }

    @Test("Corner radius scale is monotonically increasing")
    func cornerRadiiIncreasing() {
        let values = [CornerRadius.small, CornerRadius.medium, CornerRadius.large, CornerRadius.extraLarge]
        for i in 1..<values.count {
            #expect(values[i] > values[i - 1],
                    "CornerRadius[\(i)] (\(values[i])) must be > CornerRadius[\(i-1)] (\(values[i-1]))")
        }
    }

    // MARK: - Shadows

    @Test("Shadow radii increase with elevation")
    func shadowElevationOrder() {
        #expect(ShadowTokens.sm.radius < ShadowTokens.md.radius)
        #expect(ShadowTokens.md.radius < ShadowTokens.lg.radius)
    }

    @Test("All shadows have non-negative radius")
    func shadowRadiiNonNegative() {
        let shadows = [ShadowTokens.sm, ShadowTokens.md, ShadowTokens.lg]
        for shadow in shadows {
            #expect(shadow.radius >= 0)
        }
    }
}
