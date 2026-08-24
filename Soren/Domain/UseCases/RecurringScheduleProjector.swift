import Foundation

enum RecurringScheduleEvent: Equatable, Sendable {
    case scheduledCharge(itemID: UUID, date: Date, money: Money)
    case trialEnd(itemID: UUID, date: Date)
}

struct RecurringScheduleProjection: Equatable, Sendable {
    enum MonetaryCompleteness: Equatable, Sendable {
        case complete
        case unavailable
    }

    let events: [RecurringScheduleEvent]
    let monetaryCompleteness: MonetaryCompleteness
}

enum RecurringScheduleProjectionError: Error, Equatable, Sendable {
    case invalidCalendarArithmetic
}

/// Projects the schedule truth implied by one recurring item into a half-open
/// interval. Each occurrence is derived from the persisted schedule anchor,
/// so temporary calendar clamping never becomes the next recurrence anchor.
struct RecurringScheduleProjector: Sendable {
    func project(
        _ item: RecurringItem,
        in interval: Range<Date>,
        asOf referenceDate: Date,
        calendar: Calendar
    ) throws -> RecurringScheduleProjection {
        guard !interval.isEmpty else {
            return complete()
        }

        guard item.status.countsInTotals, item.archivedAt == nil else {
            return complete()
        }

        let referenceDay = calendar.startOfDay(for: referenceDate)
        let startDate = calendar.startOfDay(for: item.startDate)
        let scheduleAnchor = calendar.startOfDay(for: item.nextChargeDate)
        let endDate = item.endDate.map { calendar.startOfDay(for: $0) }

        if let endDate, endDate < referenceDay {
            return complete()
        }

        let trialBoundary = trialBoundaryEvent(
            for: item,
            in: interval,
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )

        if !item.autoRenew, endDate == nil {
            return unavailable(events: trialBoundary)
        }

        if let endDate,
           startDate > endDate || scheduleAnchor > endDate {
            return unavailable(events: trialBoundary)
        }

        let effectiveStartDate: Date
        if item.status == .trial {
            guard item.autoRenew,
                  let trialEndDate = item.trialEndDate,
                  item.nextChargeDate >= trialEndDate,
                  calendar.isDate(item.nextChargeDate, inSameDayAs: trialEndDate)
            else {
                return unavailable(events: trialBoundary)
            }

            effectiveStartDate = max(
                startDate,
                calendar.startOfDay(for: trialEndDate)
            )
        } else {
            effectiveStartDate = startDate
        }

        guard item.amount > 0,
              isValid(item.billingCycle)
        else {
            return unavailable(events: trialBoundary)
        }

        let money: Money
        do {
            money = try Money(
                amount: item.amount,
                currencyCode: item.currencyCode
            )
        } catch {
            return unavailable(events: trialBoundary)
        }

        let recurrence = try AnchoredRecurrence(
            billingCycle: item.billingCycle,
            anchor: scheduleAnchor,
            calendar: calendar
        )
        let chargeDates = try recurrence.dates(
            in: interval,
            lifecycleStart: effectiveStartDate,
            lifecycleEnd: endDate
        )
        let charges = chargeDates.map {
            RecurringScheduleEvent.scheduledCharge(
                itemID: item.id,
                date: $0,
                money: money
            )
        }

        return complete(events: trialBoundary + charges)
    }
}

// MARK: - Projection Truth

private extension RecurringScheduleProjector {
    func trialBoundaryEvent(
        for item: RecurringItem,
        in interval: Range<Date>,
        startDate: Date,
        endDate: Date?,
        calendar: Calendar
    ) -> [RecurringScheduleEvent] {
        guard item.status == .trial,
              let trialEndDate = item.trialEndDate
        else {
            return []
        }

        let boundary = calendar.startOfDay(for: trialEndDate)
        guard interval.contains(boundary),
              boundary >= startDate,
              endDate.map({ boundary <= $0 }) ?? true
        else {
            return []
        }

        return [.trialEnd(itemID: item.id, date: boundary)]
    }

    func isValid(_ billingCycle: BillingCycle) -> Bool {
        if case let .custom(days) = billingCycle {
            return days > 0
        }
        return true
    }

    func complete(
        events: [RecurringScheduleEvent] = []
    ) -> RecurringScheduleProjection {
        RecurringScheduleProjection(
            events: events,
            monetaryCompleteness: .complete
        )
    }

    func unavailable(
        events: [RecurringScheduleEvent] = []
    ) -> RecurringScheduleProjection {
        RecurringScheduleProjection(
            events: events,
            monetaryCompleteness: .unavailable
        )
    }
}

// MARK: - Anchored Recurrence

private struct AnchoredRecurrence {
    let billingCycle: BillingCycle
    let anchor: Date
    let calendar: Calendar
    let anchorMonthStart: Date
    let anchorDay: Int
    let anchorIsEndOfMonth: Bool

    init(
        billingCycle: BillingCycle,
        anchor: Date,
        calendar: Calendar
    ) throws {
        guard let anchorMonthStart = calendar.dateInterval(
            of: .month,
            for: anchor
        )?.start,
        let anchorMonthDays = calendar.range(
            of: .day,
            in: .month,
            for: anchor
        ),
        let finalAnchorDay = anchorMonthDays.last
        else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }

        let anchorDay = calendar.component(.day, from: anchor)
        self.billingCycle = billingCycle
        self.anchor = anchor
        self.calendar = calendar
        self.anchorMonthStart = anchorMonthStart
        self.anchorDay = anchorDay
        self.anchorIsEndOfMonth = anchorDay == finalAnchorDay
    }

    func dates(
        in interval: Range<Date>,
        lifecycleStart: Date,
        lifecycleEnd: Date?
    ) throws -> [Date] {
        var offset = try firstOffset(onOrAfter: interval.lowerBound)
        var candidate = try date(at: offset)
        var dates = Set<Date>()

        while candidate < interval.upperBound {
            if candidate >= lifecycleStart,
               lifecycleEnd.map({ candidate <= $0 }) ?? true {
                dates.insert(candidate)
            }

            let nextOffset = try adding(1, to: offset)
            let nextCandidate = try date(at: nextOffset)
            guard nextCandidate > candidate else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            offset = nextOffset
            candidate = nextCandidate
        }

        return dates.sorted()
    }

    func firstOffset(onOrAfter lowerBound: Date) throws -> Int {
        var offset = try estimatedOffset(for: lowerBound)
        var candidate = try date(at: offset)

        while candidate < lowerBound {
            let nextOffset = try adding(1, to: offset)
            let nextCandidate = try date(at: nextOffset)
            guard nextCandidate > candidate else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            offset = nextOffset
            candidate = nextCandidate
        }

        while true {
            let previousOffset = try adding(-1, to: offset)
            let previousCandidate = try date(at: previousOffset)
            guard previousCandidate >= lowerBound else { break }
            guard previousCandidate < candidate else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            offset = previousOffset
            candidate = previousCandidate
        }

        return offset
    }

    func estimatedOffset(for date: Date) throws -> Int {
        switch billingCycle {
        case .weekly:
            return try dayOffset(to: date, step: 7)
        case .monthly:
            return try monthOffset(to: date, step: 1)
        case .quarterly:
            return try monthOffset(to: date, step: 3)
        case .semiannual:
            return try monthOffset(to: date, step: 6)
        case .annual:
            guard let years = calendar.dateComponents(
                [.year],
                from: anchor,
                to: date
            ).year else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            return years
        case let .custom(days):
            guard days > 0 else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            return try dayOffset(to: date, step: days)
        }
    }

    func dayOffset(to date: Date, step: Int) throws -> Int {
        guard let days = calendar.dateComponents(
            [.day],
            from: anchor,
            to: date
        ).day else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return floorQuotient(days, by: step)
    }

    func monthOffset(to date: Date, step: Int) throws -> Int {
        guard let targetMonthStart = calendar.dateInterval(
            of: .month,
            for: date
        )?.start,
        let months = calendar.dateComponents(
            [.month],
            from: anchorMonthStart,
            to: targetMonthStart
        ).month else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return floorQuotient(months, by: step)
    }

    func date(at offset: Int) throws -> Date {
        switch billingCycle {
        case .weekly:
            return try dayDate(offset: offset, step: 7)
        case .monthly:
            return try monthlyFamilyDate(offset: offset, step: 1)
        case .quarterly:
            return try monthlyFamilyDate(offset: offset, step: 3)
        case .semiannual:
            return try monthlyFamilyDate(offset: offset, step: 6)
        case .annual:
            guard let date = calendar.date(
                byAdding: .year,
                value: offset,
                to: anchor
            ) else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            return date
        case let .custom(days):
            guard days > 0 else {
                throw RecurringScheduleProjectionError.invalidCalendarArithmetic
            }
            return try dayDate(offset: offset, step: days)
        }
    }

    func dayDate(offset: Int, step: Int) throws -> Date {
        let dayOffset = try multiplied(offset, by: step)
        guard let date = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: anchor
        ) else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return date
    }

    func monthlyFamilyDate(offset: Int, step: Int) throws -> Date {
        let monthOffset = try multiplied(offset, by: step)
        guard let targetMonthStart = calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: anchorMonthStart
        ),
        let targetMonthDays = calendar.range(
            of: .day,
            in: .month,
            for: targetMonthStart
        ),
        let finalTargetDay = targetMonthDays.last
        else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }

        let targetDay = anchorIsEndOfMonth
            ? finalTargetDay
            : min(anchorDay, finalTargetDay)
        guard let date = calendar.date(
            byAdding: .day,
            value: targetDay - 1,
            to: targetMonthStart
        ) else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return date
    }

    func floorQuotient(_ numerator: Int, by denominator: Int) -> Int {
        let quotient = numerator / denominator
        let remainder = numerator % denominator
        return numerator < 0 && remainder != 0 ? quotient - 1 : quotient
    }

    func adding(_ value: Int, to integer: Int) throws -> Int {
        let result = integer.addingReportingOverflow(value)
        guard !result.overflow else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return result.partialValue
    }

    func multiplied(_ value: Int, by multiplier: Int) throws -> Int {
        let result = value.multipliedReportingOverflow(by: multiplier)
        guard !result.overflow else {
            throw RecurringScheduleProjectionError.invalidCalendarArithmetic
        }
        return result.partialValue
    }
}
