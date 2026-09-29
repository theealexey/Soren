import Foundation
import Testing
@testable import Soren

@Suite("Overview month schedule rail")
struct MonthScheduleRailLayoutTests {
    private func presentation(
        daysInMonth: Int = 31,
        occurrenceDays: [Int]
    ) -> MonthSchedulePresentation {
        MonthSchedulePresentation(
            year: 2026,
            month: 9,
            daysInMonth: daysInMonth,
            todayDay: 15,
            occurrences: occurrenceDays.map {
                MonthSchedulePresentation.Occurrence(itemID: UUID(), day: $0)
            }
        )
    }

    @Test("Civil day endpoints and midpoint have canonical positions")
    func canonicalPositions() {
        let layout = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: [31, 16, 1]),
            width: 300
        )

        #expect(layout.x(for: 1) == 0)
        #expect(layout.x(for: 16) == 150)
        #expect(layout.x(for: 31) == 300)
        #expect(layout.clusters.map(\.day) == [1, 16, 31])
    }

    @Test("One through four-plus same-day occurrences retain real counts")
    func clusterSizes() {
        let layout = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: [2, 5, 5, 10, 10, 10, 20, 20, 20, 20, 20]),
            width: 360
        )

        #expect(layout.clusters.map(\.count) == [1, 2, 3, 5])
        #expect(layout.clusters.map(\.visibleDotCount) == [1, 2, 3, 3])
        #expect(layout.clusters.map(\.span) == [8, 20, 32, 32])
    }

    @Test("Overlapping clusters use the lowest free lane without changing X")
    func collisionLanes() {
        let layout = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: [3, 1, 2]),
            width: 300
        )

        #expect(layout.clusters.map(\.day) == [1, 2, 3])
        #expect(layout.clusters.map(\.lane) == [0, 1, 0])
        #expect(layout.clusters.map(\.x) == [0, 10, 20])
        #expect(layout.y(forLane: 0) - layout.y(forLane: 1) == 14)
    }

    @Test("A count label reserves extra vertical separation")
    func countLabelClearance() {
        let layout = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: [1, 1, 1, 1, 2]),
            width: 300
        )

        #expect(layout.clusters.map(\.lane) == [0, 1])
        #expect(layout.y(forLane: 0) - layout.y(forLane: 1) == 28)
        #expect(layout.clusters[0].x == 0)
    }

    @Test("Dense counts reserve count-label width and rail grows with lanes")
    func denseLayout() {
        let dense = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: Array(repeating: 1, count: 10_000) + [2]),
            width: 300
        )
        let sparse = MonthScheduleRailLayout.make(
            presentation: presentation(occurrenceDays: [1]),
            width: 300
        )

        #expect(dense.clusters[0].span > 32)
        #expect(dense.clusters[1].lane == 1)
        #expect(dense.height > sparse.height)
    }
}
