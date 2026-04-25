import Foundation

// MARK: - ItemStatus Display

/// Presentation-layer extension mapping item lifecycle states to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension ItemStatus {

    /// Localized label shown in status badges and detail rows.
    var displayName: String {
        switch self {
        case .active:    String(localized: "Активна")
        case .dueSoon:   String(localized: "Скоро списание")
        case .dueToday:  String(localized: "Списание сегодня")
        case .overdue:   String(localized: "Просрочена")
        case .trial:     String(localized: "Пробный период")
        case .failed:    String(localized: "Ошибка оплаты")
        case .cancelled: String(localized: "Отменена")
        case .paused:    String(localized: "Пауза")
        case .archived:  String(localized: "В архиве")
        }
    }
}
