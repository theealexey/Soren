import Foundation

/// Associates canonical schedule truth with its source without another fetch.
struct CalendarScheduleOccurrence: Equatable, Sendable {
    let item: RecurringItem
    let event: RecurringScheduleEvent
    let day: CivilDate

    var money: Money? {
        if case let .scheduledCharge(_, _, money) = event { return money }
        return nil
    }
}

struct CalendarSchedule: Equatable, Sendable {
    let range: Range<Date>
    let occurrences: [CalendarScheduleOccurrence]
    let monetaryCompleteness: RecurringScheduleProjection.MonetaryCompleteness
}

@MainActor
struct GetCalendarSchedule {
    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) { self.repository = repository }

    /// Half-open canonical range includes every civil day of the requested month.
    func execute(month: CivilDate, today: CivilDate) throws -> CalendarSchedule {
        let calendar = BillingCivilDay.calendar
        let first = try CivilDate(year: month.year, month: month.month, day: 1)
        let start = try BillingCivilDay.canonicalDate(for: first)
        guard let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            throw BillingCivilDayError.arithmeticFailed
        }
        let reference = try BillingCivilDay.canonicalDate(for: today)
        let items = try repository.fetchAll()
        var occurrences: [CalendarScheduleOccurrence] = []
        var completeness = RecurringScheduleProjection.MonetaryCompleteness.complete
        for item in items {
            let projection = try RecurringScheduleProjector().project(
                item, in: start..<end, asOf: reference, calendar: calendar
            )
            if projection.monetaryCompleteness == .unavailable { completeness = .unavailable }
            for event in projection.events {
                let date: Date
                switch event {
                case let .scheduledCharge(_, value, _), let .trialEnd(_, value): date = value
                }
                occurrences.append(CalendarScheduleOccurrence(
                    item: item, event: event,
                    day: try BillingCivilDay.civilDate(fromCanonicalDate: date)
                ))
            }
        }
        occurrences.sort {
            if $0.day != $1.day { return $0.day < $1.day }
            if $0.item.id != $1.item.id { return $0.item.id.uuidString < $1.item.id.uuidString }
            return $0.money == nil && $1.money != nil
        }
        return CalendarSchedule(range: start..<end, occurrences: occurrences, monetaryCompleteness: completeness)
    }
}
