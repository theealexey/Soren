import Foundation

/// One complete Gregorian month of canonical schedule truth, before FX conversion.
struct AnalyticsForecastMonth: Equatable, Sendable {
    let range: Range<Date>
    let charges: [RecurringSpendProjection]
    let eventCount: Int
    let monetaryCompleteness: RecurringScheduleProjection.MonetaryCompleteness
}

@MainActor
struct GetAnalyticsForecast {
    private let repository: any RecurringItemRepository

    init(repository: any RecurringItemRepository) { self.repository = repository }

    /// Current civil month plus five future months. Repository eligibility belongs
    /// to the canonical projector, independently of Analytics' normalized summary.
    func execute(today: CivilDate) throws -> [AnalyticsForecastMonth] {
        let calendar = BillingCivilDay.calendar
        let firstDay = try CivilDate(year: today.year, month: today.month, day: 1)
        let start = try BillingCivilDay.canonicalDate(for: firstDay)
        let reference = try BillingCivilDay.canonicalDate(for: today)
        let ranges = try (0..<6).map { offset -> Range<Date> in
            guard let lower = calendar.date(byAdding: .month, value: offset, to: start),
                  let upper = calendar.date(byAdding: .month, value: offset + 1, to: start)
            else { throw BillingCivilDayError.arithmeticFailed }
            return lower..<upper
        }
        guard let end = ranges.last?.upperBound else { throw BillingCivilDayError.arithmeticFailed }
        let items = try repository.fetchAll()
        let projector = RecurringScheduleProjector()
        var events: [RecurringScheduleEvent] = []
        var completeness = RecurringScheduleProjection.MonetaryCompleteness.complete
        for item in items {
            let projection = try projector.project(item, in: start..<end, asOf: reference, calendar: calendar)
            events.append(contentsOf: projection.events)
            if projection.monetaryCompleteness == .unavailable { completeness = .unavailable }
        }
        return ranges.map { range in
            var charges: [RecurringSpendProjection] = []
            var eventCount = 0
            for event in events {
                switch event {
                case let .scheduledCharge(_, date, money) where range.contains(date):
                    eventCount += 1
                    charges.append(RecurringSpendProjection(
                        date: date, amount: money.amount, currencyCode: money.currencyCode
                    ))
                case let .trialEnd(_, date) where range.contains(date):
                    eventCount += 1
                default:
                    break
                }
            }
            charges.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                if $0.currencyCode != $1.currencyCode { return $0.currencyCode < $1.currencyCode }
                return $0.amount < $1.amount
            }
            return AnalyticsForecastMonth(range: range, charges: charges, eventCount: eventCount,
                                          monetaryCompleteness: completeness)
        }
    }
}
