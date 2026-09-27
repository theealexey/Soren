import Foundation

/// One monetary charge in the canonical projected schedule.
struct UpcomingScheduledCharge: Equatable, Sendable {
    let item: RecurringItem
    let date: Date
    let money: Money
}

enum GetUpcomingChargesError: Error, Equatable, Sendable {
    case invalidCalendarArithmetic
}

/// Returns the nearest monetary schedule occurrences in the next Gregorian year.
@MainActor
struct GetUpcomingCharges {
    private let repository: any RecurringItemRepository
    private let projector = RecurringScheduleProjector()

    init(repository: any RecurringItemRepository) {
        self.repository = repository
    }

    func execute(from today: Date, calendar: Calendar) throws -> [UpcomingScheduledCharge] {
        let start = calendar.startOfDay(for: today)
        guard let anniversary = calendar.date(byAdding: .year, value: 1, to: start),
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: anniversary),
              start < endExclusive
        else {
            throw GetUpcomingChargesError.invalidCalendarArithmetic
        }

        let items = try repository.fetchAll()
        var occurrences: [UpcomingScheduledCharge] = []
        for item in items {
            let projection = try projector.project(
                item,
                in: start..<endExclusive,
                asOf: start,
                calendar: calendar
            )
            for event in projection.events {
                guard case let .scheduledCharge(_, date, money) = event else { continue }
                occurrences.append(UpcomingScheduledCharge(item: item, date: date, money: money))
            }
        }

        return Array(occurrences.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.item.id.uuidString < $1.item.id.uuidString
        }.prefix(3))
    }
}
