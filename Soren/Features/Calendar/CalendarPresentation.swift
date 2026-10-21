import Foundation

/// Visual compression only. The selected-day agenda keeps the complete event array.
struct CalendarDayPresentation {
    let day: CalendarDay
    let isSelected: Bool
    let occurrences: [CalendarScheduleOccurrence]

    var isInteractive: Bool { day.isCurrentMonth }
    var isToday: Bool { day.isCurrentMonth && day.isToday }
    var visibleMarks: [CalendarScheduleOccurrence] {
        day.isCurrentMonth ? Array(occurrences.prefix(2)) : []
    }
    var overflowCount: Int { day.isCurrentMonth ? max(0, occurrences.count - 2) : 0 }
    var scheduledChargeCount: Int { occurrences.filter { $0.money != nil }.count }
    var trialEndCount: Int { occurrences.count - scheduledChargeCount }

    func accessibilityLabel(calendar: Calendar) -> String {
        let formatter = PresentationLocale.dateFormatter(template: "EEEE d MMMM yyyy", calendar: calendar)
        formatter.timeZone = calendar.timeZone
        var parts = [formatter.string(from: day.date)]
        if isToday { parts.append(String(localized: "Сегодня")) }
        if day.isCurrentMonth {
            parts.append(String(localized: "\(scheduledChargeCount) списаний"))
            parts.append(String(localized: "\(trialEndCount) пробных"))
        }
        return parts.joined(separator: ", ")
    }
}

enum CalendarPresentation {
    static func selectedDayTitle(day: CalendarDay, calendar: Calendar) -> String {
        if day.isToday { return String(localized: "Сегодня") }
        let formatter = PresentationLocale.dateFormatter(template: "d MMMM", calendar: calendar)
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: day.date)
    }

    static func metadata(for occurrence: CalendarScheduleOccurrence) -> String {
        if occurrence.money == nil { return String(localized: "Пробный период заканчивается") }
        let cycle = RecurringItemFormatter.cycleLabel(for: occurrence.item.billingCycle).accessibilityText
        let provider = occurrence.item.providerName
        if !provider.isEmpty, provider != occurrence.item.title {
            return "\(provider) · \(cycle)"
        }
        return cycle
    }
}
