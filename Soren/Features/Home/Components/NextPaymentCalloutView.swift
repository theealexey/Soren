import SwiftUI

// MARK: - Next Payment Callout View

/// Renders all four states of NextPaymentCalloutState.
///
/// Layout contract:
///   • .nextPayment  — countdown + service name / trailing amount
///   • .selectedDay  — date header + charge list / trailing total
///   • .emptyDay     — date label + "No charges" note
///   • .noUpcoming   — single muted line when no charges exist in the window
///
/// Typography rules (per spec):
///   • Primary callout text (countdown / date)  → Typography.title
///   • Hero amount                              → Typography.amountLarge
///   • Secondary labels, service names          → Typography.caption
///   • Charge-row amounts                       → Typography.amountSmall
struct NextPaymentCalloutView: View {

    let state: NextPaymentCalloutState

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state {
            case let .nextPayment(countdown, name, amountFormatted, additionalCount):
                nextPaymentLayout(
                    countdown: countdown,
                    name: name,
                    amountFormatted: amountFormatted,
                    additionalCount: additionalCount
                )

            case let .selectedDay(selection):
                selectedDayLayout(selection: selection)

            case let .emptyDay(formattedDate):
                emptyDayLayout(formattedDate: formattedDate)

            case .noUpcoming:
                noUpcomingLayout()
            }
        }
        .padding(.horizontal, Spacing.lg)
        .animation(MotionTokens.smooth, value: state)
    }

    // MARK: - Next Payment

    private func nextPaymentLayout(
        countdown: String,
        name: String,
        amountFormatted: String,
        additionalCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(countdown)
                    .font(Typography.title)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Text(amountFormatted)
                    .font(Typography.amountLarge)
                    .foregroundStyle(theme.primaryText)
            }

            HStack(spacing: Spacing.xxs) {
                Text(name)
                    .foregroundStyle(theme.secondaryText)

                if additionalCount > 0 {
                    Text("·")
                        .foregroundStyle(theme.tertiaryText)
                    Text("и ещё \(additionalCount)")
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .font(Typography.caption)
        }
    }

    // MARK: - Selected Day

    private func selectedDayLayout(selection: BillingLandscapeSelection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(selection.formattedDate)
                    .font(Typography.title)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Text(selection.totalFormatted)
                    .font(Typography.amountLarge)
                    .foregroundStyle(theme.primaryText)
            }

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                ForEach(selection.charges.prefix(3)) { charge in
                    HStack {
                        Text(charge.name)
                            .font(Typography.caption)
                            .foregroundStyle(theme.secondaryText)

                        Spacer()

                        Text(charge.amountFormatted)
                            .font(Typography.amountSmall)
                            .foregroundStyle(theme.tertiaryText)
                    }
                }

                if selection.charges.count > 3 {
                    Text("и ещё \(selection.charges.count - 3)")
                        .font(Typography.footnote)
                        .foregroundStyle(theme.tertiaryText)
                }
            }
        }
    }

    // MARK: - No Upcoming

    private func noUpcomingLayout() -> some View {
        Text(String(localized: "Нет предстоящих списаний"))
            .font(Typography.title)
            .foregroundStyle(theme.tertiaryText)
    }

    // MARK: - Empty Day

    private func emptyDayLayout(formattedDate: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            Text(formattedDate)
                .font(Typography.title)
                .foregroundStyle(theme.primaryText)

            Text(String(localized: "Нет списаний"))
                .font(Typography.caption)
                .foregroundStyle(theme.tertiaryText)
        }
    }
}
