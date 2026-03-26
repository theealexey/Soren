import SwiftUI

// MARK: - Provider Icon

/// Displays a service provider icon with consistent sizing.
/// Supports SF Symbols as default, with future support for custom brand assets.
///
/// Usage:
/// ```swift
/// ProviderIcon(systemName: "play.rectangle.fill", color: .red)
/// ProviderIcon(systemName: "star.fill", color: .purple, size: .large)
/// ```
struct ProviderIcon: View {
    let systemName: String
    let color: Color
    let size: Size

    init(systemName: String, color: Color = ColorTokens.accent, size: Size = .medium) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size.frame, height: size.frame)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size.radius))
    }
}

// MARK: - Size

extension ProviderIcon {
    enum Size {
        /// 28pt frame — compact lists, secondary display.
        case small
        /// 40pt frame — standard list rows.
        case medium
        /// 56pt frame — detail screen hero, catalog cards.
        case large

        var frame: CGFloat {
            switch self {
            case .small:  28
            case .medium: 40
            case .large:  56
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small:  12
            case .medium: 16
            case .large:  22
            }
        }

        var radius: CGFloat {
            switch self {
            case .small:  CornerRadius.small
            case .medium: CornerRadius.medium
            case .large:  CornerRadius.medium
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: Spacing.md) {
        ProviderIcon(systemName: "play.rectangle.fill", color: .red, size: .small)
        ProviderIcon(systemName: "star.fill", color: .purple, size: .medium)
        ProviderIcon(systemName: "icloud.fill", color: ColorTokens.categoryCloud, size: .large)
    }
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
