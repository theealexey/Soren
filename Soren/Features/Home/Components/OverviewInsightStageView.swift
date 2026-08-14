import SwiftUI

/// The accepted editorial Insight Stage: one selected insight, directly on canvas.
struct OverviewInsightStageView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var normalFinancialValueSize: CGFloat = 36
    @ScaledMetric(relativeTo: .title2) private var normalStatementSize: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var normalEyebrowSize: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var normalSupportingSize: CGFloat = 14

    let presentation: OverviewInsightPresentation

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                normalLayout
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: dynamicTypeSize.isAccessibilitySize ? 0 : 104,
            alignment: .topLeading
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private var normalLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            signatureRegister
                .padding(.top, 25)

            VStack(alignment: .leading, spacing: 8) {
                eyebrow

                primaryContent

                supporting
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            eyebrow

            HStack(alignment: .top, spacing: 12) {
                signatureRegister
                    .padding(.top, 5)
                primaryContent
            }

            supporting
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryContent: some View {
        switch presentation.primaryStyle {
        case .financialValue:
            Text(verbatim: presentation.primary)
                .font(financialValueFont)
                .monospacedDigit()
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        case .statement:
            Text(verbatim: presentation.primary)
                .font(statementFont)
                .foregroundStyle(SoftClubColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var eyebrow: some View {
        Text(verbatim: presentation.eyebrow)
            .font(eyebrowFont)
            .tracking(0.85)
            .foregroundStyle(SoftClubColor.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var supporting: some View {
        Text(verbatim: presentation.supporting)
            .font(supportingFont)
            .foregroundStyle(SoftClubColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var financialValueFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: normalFinancialValueSize, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 38,
            accessibility3: 42,
            accessibility5: 46
        ))
    }

    private var statementFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: normalStatementSize, weight: .medium)
        }
        return .system(
            size: OverviewAccessibilityTypeScale.size(
                for: dynamicTypeSize,
                accessibility1: 23,
                accessibility3: 26,
                accessibility5: 29
            ),
            weight: .medium
        )
    }

    private var eyebrowFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: normalEyebrowSize, weight: .medium)
        }
        return .system(
            size: OverviewAccessibilityTypeScale.size(
                for: dynamicTypeSize,
                accessibility1: 12.5,
                accessibility3: 14,
                accessibility5: 15.5
            ),
            weight: .medium
        )
    }

    private var supportingFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else {
            return .system(size: normalSupportingSize, weight: .regular)
        }
        return .system(size: OverviewAccessibilityTypeScale.size(
            for: dynamicTypeSize,
            accessibility1: 16,
            accessibility3: 18,
            accessibility5: 20
        ))
    }

    private var signatureRegister: some View {
        RoundedRectangle(cornerRadius: 0.8, style: .continuous)
            .fill(SoftClubColor.signatureRed)
            .frame(width: 2, height: 24)
            .accessibilityHidden(true)
    }
}
