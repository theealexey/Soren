import SwiftUI

// MARK: - Soren List Row

/// Universal row for subscription/payment lists.
/// Used across Home (upcoming), Library, Search results, Alerts.
///
/// Displays: icon/logo → title + subtitle → amount + cycle badge.
///
/// When `providerTemplate` is set (item was added from the catalog), the leading icon
/// uses `ProviderIcon` (bundled asset → verified remote fallback → letter-mark).
/// Otherwise the category SF Symbol is shown.
///
/// Usage:
/// ```swift
/// SorenListRow(
///     title: "YouTube Premium",
///     subtitle: "Next charge: Apr 12",
///     amount: 299,
///     currency: "RUB",
///     cycle: .monthly,
///     providerTemplate: ProviderCatalog.template(forProviderID: item.providerID),
///     category: .video
/// )
/// ```
struct SorenListRow: View {

    /// Leading inset for dividers between rows (icon width + row spacing).
    /// References ProviderIcon.Size.medium.frame so it stays in sync if icon sizes change.
    static let dividerInset: CGFloat = ProviderIcon.Size.medium.frame + Spacing.sm

    let title: String
    let subtitle: String?
    let amount: Decimal
    let currencyCode: String
    let cycle: AmountLabel.CycleLabel?
    let providerTemplate: ProviderTemplate?
    let category: ItemCategory
    let badge: Badge?

    init(
        title: String,
        subtitle: String? = nil,
        amount: Decimal,
        currency currencyCode: String = "RUB",
        cycle: AmountLabel.CycleLabel? = .monthly,
        providerTemplate: ProviderTemplate? = nil,
        category: ItemCategory = .other,
        badge: Badge? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.currencyCode = currencyCode
        self.cycle = cycle
        self.providerTemplate = providerTemplate
        self.category = category
        self.badge = badge
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            iconView
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack(spacing: Spacing.xs) {
                    Text(title)
                        .font(Typography.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                        .lineLimit(1)

                    if let badge {
                        BadgeView(badge: badge)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: Spacing.xs)

            AmountLabel(amount, currency: currencyCode, size: .medium, cycle: cycle)
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
    }

    private static var currencyFormatters: [String: NumberFormatter] = [:]

    private static func currencyFormatter(for code: String) -> NumberFormatter {
        if let cached = currencyFormatters[code] { return cached }
        let f = NumberFormatter()
        f.numberStyle         = .currency
        f.currencyCode        = code
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        currencyFormatters[code] = f
        return f
    }

    private var rowAccessibilityLabel: String {
        var parts: [String] = [title]
        if let badge { parts.append(badge.title) }
        let fmt = Self.currencyFormatter(for: currencyCode)
        let amountStr = fmt.string(from: amount as NSDecimalNumber) ?? "\(amount) \(currencyCode)"
        let cycleStr = cycle.map { " \($0.accessibilityText)" } ?? ""
        parts.append("\(amountStr)\(cycleStr)")
        if let subtitle { parts.append(subtitle) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var iconView: some View {
        if let provider = providerTemplate {
            ProviderIcon(provider: provider, size: .medium)
        } else {
            Image(systemName: category.systemIconName)
                .font(Typography.bodyMedium)
                .foregroundStyle(.white)
                .frame(width: ProviderIcon.Size.medium.frame, height: ProviderIcon.Size.medium.frame)
                .background(category.color.gradient, in: RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
}

// MARK: - Badge

extension SorenListRow {
    enum Badge: Equatable {
        case trial
        case dueSoon
        case failed
        case paused
        case annual

        var title: String {
            switch self {
            case .trial:   String(localized: "Пробный")
            case .dueSoon: String(localized: "Скоро")
            case .failed:  String(localized: "Ошибка")
            case .paused:  String(localized: "Пауза")
            case .annual:  String(localized: "Годовая")
            }
        }

        var color: Color {
            switch self {
            case .trial:   ColorTokens.warning
            case .dueSoon: ColorTokens.info
            case .failed:  ColorTokens.error
            case .paused:  ColorTokens.textTertiary
            case .annual:  ColorTokens.accent
            }
        }
    }
}

// MARK: - Badge View

private struct BadgeView: View {
    let badge: SorenListRow.Badge

    var body: some View {
        Text(badge.title)
            .font(Typography.footnote)
            .fontWeight(.medium)
            .foregroundStyle(badge.color)
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, Spacing.xxxs)
            .background(badge.color.opacity(0.12), in: Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SorenListRow(
            title: "YouTube Premium",
            subtitle: "Списание: 12 апр",
            amount: 299,
            currency: "RUB",
            providerTemplate: ProviderCatalog.template(forProviderID: "youtube_premium"),
            category: .video
        )

        Divider().padding(.leading, SorenListRow.dividerInset)

        SorenListRow(
            title: "Яндекс Плюс",
            subtitle: "Триал заканчивается через 3 дня",
            amount: 399,
            currency: "RUB",
            category: .shopping,
            badge: .trial
        )

        Divider().padding(.leading, SorenListRow.dividerInset)

        SorenListRow(
            title: "iCloud+ 200GB",
            subtitle: "Ежемесячное списание",
            amount: 2.99,
            currency: "USD",
            category: .cloud,
            badge: .annual
        )
    }
    .padding(.horizontal, Spacing.lg)
    .background(ColorTokens.background)
}
