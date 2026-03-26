import Testing
import SwiftUI
@testable import Soren

@Suite("InsightCard — Severity System")
@MainActor
struct InsightCardTests {

    @Test("Info severity maps to info color token")
    func infoColor() {
        #expect(InsightCard.Severity.info.color == ColorTokens.info)
    }

    @Test("Warning severity maps to warning color token")
    func warningColor() {
        #expect(InsightCard.Severity.warning.color == ColorTokens.warning)
    }

    @Test("Critical severity maps to error color token")
    func criticalColor() {
        #expect(InsightCard.Severity.critical.color == ColorTokens.error)
    }

    @Test("Positive severity maps to success color token")
    func positiveColor() {
        #expect(InsightCard.Severity.positive.color == ColorTokens.success)
    }

    // MARK: - Card creation edge cases

    @Test("Card with nil subtitle doesn't crash")
    func nilSubtitle() {
        let card = InsightCard(icon: "bolt", title: "Test", subtitle: nil, severity: .info)
        #expect(card.subtitle == nil)
    }

    @Test("Card with empty title")
    func emptyTitle() {
        let card = InsightCard(icon: "bolt", title: "", severity: .info)
        #expect(card.title.isEmpty)
    }

    @Test("Card with very long title")
    func longTitle() {
        let long = String(repeating: "A", count: 500)
        let card = InsightCard(icon: "bolt", title: long, severity: .info)
        #expect(card.title.count == 500)
    }
}
