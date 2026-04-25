import Foundation

// MARK: - BillingCycle Display

/// Presentation-layer extension mapping billing cycles to localized display strings.
/// Keeps the Domain layer free of String(localized:) dependencies.
extension BillingCycle {

    /// Full localized name shown in Pickers and detail rows.
    var displayName: String {
        switch self {
        case .weekly:            String(localized: "Еженедельно")
        case .monthly:           String(localized: "Ежемесячно")
        case .quarterly:         String(localized: "Раз в квартал")
        case .semiannual:        String(localized: "Раз в полгода")
        case .annual:            String(localized: "Ежегодно")
        case .custom(let d):     String(localized: "Каждые \(d) дн.")
        }
    }

    /// Abbreviated localized label used in compact UI contexts (chips, badges).
    var shortName: String {
        switch self {
        case .weekly:            String(localized: "нед")
        case .monthly:           String(localized: "мес")
        case .quarterly:         String(localized: "кв")
        case .semiannual:        String(localized: "п/г")
        case .annual:            String(localized: "год")
        case .custom(let d):     String(localized: "\(d)д")
        }
    }
}
