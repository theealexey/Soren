import Testing
import SwiftUI
@testable import Soren

@Suite("PremiumCard — Style System")
@MainActor
struct PremiumCardTests {

    // MARK: - Style equality

    @Test("Standard == Standard")
    func standardEquality() {
        #expect(PremiumCard<EmptyView>.Style.standard == .standard)
    }

    @Test("Elevated == Elevated")
    func elevatedEquality() {
        #expect(PremiumCard<EmptyView>.Style.elevated == .elevated)
    }

    @Test("Glass == Glass")
    func glassEquality() {
        #expect(PremiumCard<EmptyView>.Style.glass == .glass)
    }

    @Test("Standard != Elevated")
    func standardNotElevated() {
        #expect(PremiumCard<EmptyView>.Style.standard != .elevated)
    }

    @Test("Standard != Glass")
    func standardNotGlass() {
        #expect(PremiumCard<EmptyView>.Style.standard != .glass)
    }

    @Test("Elevated != Glass")
    func elevatedNotGlass() {
        #expect(PremiumCard<EmptyView>.Style.elevated != .glass)
    }

    @Test("Tinted with different colors still considered equal — design decision")
    func tintedEquality() {
        let a = PremiumCard<EmptyView>.Style.tinted(.red)
        let b = PremiumCard<EmptyView>.Style.tinted(.blue)
        #expect(a == b)
    }

    @Test("Tinted != Standard")
    func tintedNotStandard() {
        #expect(PremiumCard<EmptyView>.Style.tinted(.red) != .standard)
    }

    // MARK: - All styles produce valid backgrounds

    @Test("All styles return valid background and border")
    func allStylesHaveBackground() {
        let styles: [PremiumCard<EmptyView>.Style] = [
            .standard, .elevated, .glass,
            .tinted(.red), .tinted(.clear), .tinted(.white),
        ]
        for style in styles {
            _ = style.background
            _ = style.border
        }
    }

    @Test("Tinted with opacity-zero color doesn't crash")
    func tintedZeroOpacity() {
        let style = PremiumCard<EmptyView>.Style.tinted(.red.opacity(0))
        _ = style.background
        _ = style.border
    }
}
