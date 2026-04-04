import SwiftUI

// MARK: - Premium Card

/// Universal card container used across all screens.
/// Provides consistent surface, padding, corner radius, and optional elevation.
///
/// Usage:
/// ```swift
/// PremiumCard {
///     Text("Content")
/// }
///
/// PremiumCard(.elevated) {
///     StatBlock(...)
/// }
/// ```
struct PremiumCard<Content: View>: View {
    let style: Style
    @ViewBuilder let content: Content

    init(_ style: Style = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(style.background, in: shape)
            .overlay {
                shape
                    .strokeBorder(style.border, lineWidth: style.borderWidth)
                    .allowsHitTesting(false)
            }
            .if(style == .elevated) { view in
                view.elevation(ShadowTokens.md)
            }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Card Styles

extension PremiumCard {
    enum Style: Equatable {
        /// Default surface card — solid background, subtle border.
        case standard

        /// Raised card with shadow — for primary content blocks.
        case elevated

        /// Glass material card — for overlays on rich backgrounds.
        case glass

        /// Accent-tinted card — for highlighted insights, warnings.
        case tinted(Color)

        var background: AnyShapeStyle {
            switch self {
            case .standard:
                AnyShapeStyle(ColorTokens.surface)
            case .elevated:
                AnyShapeStyle(ColorTokens.surface)
            case .glass:
                AnyShapeStyle(.ultraThinMaterial)
            case .tinted(let color):
                AnyShapeStyle(color.opacity(0.12))
            }
        }

        var border: AnyShapeStyle {
            switch self {
            case .standard:
                AnyShapeStyle(ColorTokens.separator.opacity(0.5))
            case .elevated:
                AnyShapeStyle(.clear)
            case .glass:
                AnyShapeStyle(.white.opacity(0.15))
            case .tinted(let color):
                AnyShapeStyle(color.opacity(0.2))
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .elevated: 0
            default: 0.5
            }
        }

        static func == (lhs: Style, rhs: Style) -> Bool {
            switch (lhs, rhs) {
            case (.standard, .standard),
                 (.elevated, .elevated),
                 (.glass, .glass):
                true
            case (.tinted(let l), .tinted(let r)):
                l == r
            default:
                false
            }
        }
    }
}

// MARK: - Conditional Modifier

private extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Spacing.md) {
            PremiumCard {
                Text("Стандартная карточка")
                    .font(Typography.headline)
            }

            PremiumCard(.elevated) {
                Text("Приподнятая карточка")
                    .font(Typography.headline)
            }

            PremiumCard(.glass) {
                Text("Стеклянная карточка")
                    .font(Typography.headline)
            }

            PremiumCard(.tinted(ColorTokens.warning)) {
                Text("Предупреждение")
                    .font(Typography.headline)
            }
        }
        .padding(Spacing.lg)
    }
    .background(ColorTokens.background)
}
