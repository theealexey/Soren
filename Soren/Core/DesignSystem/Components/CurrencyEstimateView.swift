import SwiftUI

// MARK: - Currency Estimate View

/// Compact, read-only reporting-currency estimate shown below the original charge.
/// The editable amount and currency remain the subscription's persisted source values.
struct CurrencyEstimateView: View {
    let state: CurrencyEstimateState

    var body: some View {
        switch state {
        case .available(let result):
            availableEstimate(result)
        case .unavailable:
            Text("Курсы валют недоступны")
                .font(Typography.footnote)
                .foregroundStyle(ColorTokens.textTertiary)
        case .hidden, .loading:
            EmptyView()
        }
    }

    private func availableEstimate(_ result: ConversionResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs) {
                Text(verbatim: "≈")
                    .font(Typography.amountSmall)
                    .foregroundStyle(ColorTokens.textSecondary)

                AmountLabel(
                    result.converted.amount,
                    currency: result.converted.currencyCode,
                    size: .small,
                    tint: ColorTokens.textSecondary
                )
            }

            Text(freshnessLabel(for: result))
                .font(Typography.footnote)
                .foregroundStyle(freshnessColor(for: result.freshness))
        }
        .accessibilityElement(children: .combine)
    }

    private func freshnessLabel(for result: ConversionResult) -> String {
        let date = result.rateDate.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .locale(PresentationLocale.current)
        )

        switch result.freshness {
        case .fresh:
            return String(localized: "Оценка по курсу на \(date)")
        case .stale:
            return String(localized: "Сохранённый курс от \(date)")
        }
    }

    private func freshnessColor(for freshness: ExchangeRateFreshness) -> Color {
        switch freshness {
        case .fresh:
            ColorTokens.textTertiary
        case .stale:
            ColorTokens.warning
        }
    }
}
