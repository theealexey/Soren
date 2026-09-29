import SwiftUI

/// Positions canonical monthly occurrences by their Gregorian civil day.
/// This view performs visual clustering only; recurrence is resolved in Domain.
struct MonthScheduleRailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .footnote) private var dateLabelSize: CGFloat = 13

    let presentation: MonthSchedulePresentation

    @State private var availableWidth: CGFloat = 320

    var body: some View {
        let layout = MonthScheduleRailLayout.make(
            presentation: presentation,
            width: availableWidth
        )

        GeometryReader { geometry in
            let actualLayout = MonthScheduleRailLayout.make(
                presentation: presentation,
                width: geometry.size.width
            )

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(SoftClubColor.subtleSeparator)
                    .frame(height: 1)
                    .offset(y: actualLayout.railY)
                    .accessibilityHidden(true)

                if (1...presentation.daysInMonth).contains(presentation.todayDay) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(SoftClubColor.signatureRed)
                        .frame(width: 2, height: 18)
                        .position(
                            x: actualLayout.x(for: presentation.todayDay),
                            y: actualLayout.railY
                        )
                        .accessibilityLabel(String(localized: "Сегодня"))
                }

                ForEach(actualLayout.clusters) { cluster in
                    MonthScheduleDotCluster(
                        cluster: cluster,
                        month: presentation.month,
                        year: presentation.year
                    )
                    .position(x: cluster.x, y: actualLayout.y(forLane: cluster.lane))
                }

                ForEach(actualLayout.labelDays, id: \.self) { day in
                    Text(day.formatted())
                        .font(.system(size: dateLabelSize))
                        .foregroundStyle(SoftClubColor.textSecondary)
                        .fixedSize()
                        .position(x: actualLayout.x(for: day), y: actualLayout.railY + 27)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: geometry.size.width, height: actualLayout.height)
        }
        .frame(height: layout.height)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { _, newWidth in
            guard newWidth > 0, newWidth != availableWidth else { return }
            availableWidth = newWidth
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: layout.height)
    }
}

private struct MonthScheduleDotCluster: View {
    let cluster: MonthScheduleRailLayout.Cluster
    let month: Int
    let year: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<cluster.visibleDotCount, id: \.self) { _ in
                Circle()
                    .fill(SoftClubColor.textPrimary)
                    .frame(width: 8, height: 8)
            }
        }
        .overlay(alignment: .top) {
            if cluster.count >= 4 {
                Text(cluster.count.formatted())
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize()
                    .offset(y: -18)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: cluster.span)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(accessibleDate), \(String(localized: "\(cluster.count) списаний"))"
        )
    }

    private var accessibleDate: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        guard let date = calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: cluster.day,
            hour: 12
        )) else {
            return "\(cluster.day).\(month).\(year)"
        }
        let formatter = PresentationLocale.dateFormatter(template: "d MMMM yyyy", calendar: calendar)
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }
}

/// Pure, width-dependent visual layout. Civil-day X never changes to avoid collisions.
struct MonthScheduleRailLayout {
    struct Cluster: Identifiable {
        let day: Int
        let count: Int
        let lane: Int
        let x: CGFloat
        let span: CGFloat

        var id: Int { day }
        var visibleDotCount: Int { min(count, 3) }
    }

    let clusters: [Cluster]
    let labelDays: [Int]
    let railY: CGFloat
    let height: CGFloat
    let width: CGFloat
    let daysInMonth: Int
    private let laneOffsets: [CGFloat]

    func x(for day: Int) -> CGFloat {
        guard daysInMonth > 1 else { return 0 }
        return CGFloat(day - 1) / CGFloat(daysInMonth - 1) * width
    }

    func y(forLane lane: Int) -> CGFloat {
        railY - laneOffsets[lane]
    }

    static func make(presentation: MonthSchedulePresentation, width: CGFloat) -> Self {
        let width = max(0, width)
        let daysInMonth = max(1, presentation.daysInMonth)
        let counts = Dictionary(grouping: presentation.occurrences.map(\.day), by: { $0 })
            .mapValues(\.count)
        var occupied: [[Cluster]] = []
        var clusters: [Cluster] = []

        for day in counts.keys.sorted() where (1...daysInMonth).contains(day) {
            let count = counts[day, default: 0]
            let x = daysInMonth > 1
                ? CGFloat(day - 1) / CGFloat(daysInMonth - 1) * width
                : 0
            let dotSpan = CGFloat(min(count, 3) * 8 + max(0, min(count, 3) - 1) * 4)
            let countSpan = count >= 4 ? CGFloat(String(count).count * 8 + 4) : 0
            let span = max(dotSpan, countSpan)

            var lane = 0
            while lane < occupied.count,
                  occupied[lane].contains(where: {
                      abs($0.x - x) < ($0.span + span) / 2 + 4
                  }) {
                lane += 1
            }
            if lane == occupied.count { occupied.append([]) }

            let cluster = Cluster(day: day, count: count, lane: lane, x: x, span: span)
            occupied[lane].append(cluster)
            clusters.append(cluster)
        }

        var laneOffsets: [CGFloat] = [0]
        if occupied.count > 1 {
            for lane in 1..<occupied.count {
                let lowerLaneHasCount = occupied[lane - 1].contains { $0.count >= 4 }
                laneOffsets.append(laneOffsets[lane - 1] + (lowerLaneHasCount ? 28 : 14))
            }
        }
        let railY = 24 + (laneOffsets.last ?? 0)
        let labelCandidates = clusters.isEmpty ? [1, daysInMonth] : clusters.map(\.day)
        var labelDays: [Int] = []
        for day in labelCandidates {
            let x = daysInMonth > 1
                ? CGFloat(day - 1) / CGFloat(daysInMonth - 1) * width
                : 0
            let isSeparated = labelDays.allSatisfy { existing in
                let existingX = CGFloat(existing - 1) / CGFloat(max(1, daysInMonth - 1)) * width
                return abs(existingX - x) >= 34
            }
            if isSeparated { labelDays.append(day) }
        }
        if labelDays.count > 4 {
            let lastIndex = labelDays.count - 1
            labelDays = [
                labelDays[0],
                labelDays[lastIndex / 3],
                labelDays[lastIndex * 2 / 3],
                labelDays[lastIndex],
            ]
        }

        return Self(
            clusters: clusters,
            labelDays: labelDays,
            railY: railY,
            height: railY + 38,
            width: width,
            daysInMonth: daysInMonth,
            laneOffsets: laneOffsets
        )
    }
}
