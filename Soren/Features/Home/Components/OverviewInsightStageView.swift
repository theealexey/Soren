import SwiftUI

/// The accepted semantic Attention treatment, directly on the Overview canvas.
struct OverviewInsightStageView: View {
    let presentation: OverviewInsightPresentation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(SoftClubColor.signatureRed.opacity(0.78))
                .frame(width: 1.25, height: 16)
                .padding(.top, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: presentation.primary)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(SoftClubColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verbatim: presentation.supporting)
                    .font(.subheadline)
                    .foregroundStyle(SoftClubColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }
}
