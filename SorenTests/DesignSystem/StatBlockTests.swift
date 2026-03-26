import Testing
@testable import Soren

@Suite("StatBlock — Trend System")
@MainActor
struct StatBlockTests {

    // MARK: - Trend badge creation

    @Test("Trend up badge creates successfully")
    func trendUp() {
        _ = TrendBadge(trend: .up(12.5))
    }

    @Test("Trend down badge creates successfully")
    func trendDown() {
        _ = TrendBadge(trend: .down(3))
    }

    @Test("Trend flat badge creates successfully")
    func trendFlat() {
        _ = TrendBadge(trend: .flat)
    }

    // MARK: - Edge cases for trend percentages

    @Test("Trend with zero percentage")
    func trendZeroPercent() {
        _ = TrendBadge(trend: .up(0))
    }

    @Test("Trend with 100% increase")
    func trend100Percent() {
        _ = TrendBadge(trend: .up(100))
    }

    @Test("Trend with very large percentage")
    func trendHugePercent() {
        _ = TrendBadge(trend: .up(9999.9))
    }

    // MARK: - StatBlock creation

    @Test("StatBlock with nil trend")
    func nilTrend() {
        let block = StatBlock(title: "Monthly", amount: 0, currency: "RUB", trend: nil)
        #expect(block.trend == nil)
    }

    @Test("StatBlock with zero amount")
    func zeroAmount() {
        let block = StatBlock(title: "Yearly", amount: 0, currency: "RUB")
        #expect(block.amount == 0)
    }

    @Test("StatBlock with negative amount — debt/refund scenario")
    func negativeAmount() {
        let block = StatBlock(title: "Balance", amount: -500, currency: "RUB")
        #expect(block.amount == -500)
    }
}
