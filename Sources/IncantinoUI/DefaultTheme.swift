import SwiftUI

/// Default theme with neutral iOS-native appearance.
/// Uses system colors and standard fonts as sensible defaults.
@MainActor
public final class DefaultTheme: ThemeReading, Observable {
    public init() {}

    // MARK: - Colors

    public var background: Color { Color(.systemBackground) }
    public var surface: Color { Color(.secondarySystemBackground) }
    public var surfaceElevated: Color { Color(.systemBackground) }
    public var accent: Color { .accentColor }
    public var accentSecondary: Color { .purple }
    public var textPrimary: Color { Color(.label) }
    public var textSecondary: Color { Color(.secondaryLabel) }
    public var textTertiary: Color { .secondary }
    public var separator: Color { Color(.separator) }
    public var error: Color { .red }
    public var success: Color { .green }
    public var transit: Color { .orange }
    public var warning: Color { .orange }
    public var cardFill: Color { Color(.secondarySystemBackground) }
    public var badgeBackground: Color { .red }
    public var badgeText: Color { .white }
    public var brandGradientStart: Color { .accentColor }
    public var brandGradientEnd: Color { .purple }
    public var completedStep: Color { .green }
    public var overlayButtonBackground: Color { Color.black.opacity(0.8) }
    public var borderColor: Color { Color(.separator) }

    // MARK: - Spacing

    public var spacingXS: CGFloat { 4 }
    public var spacingSM: CGFloat { 8 }
    public var spacingMD: CGFloat { 16 }
    public var spacingLG: CGFloat { 24 }
    public var spacingXL: CGFloat { 32 }
    public var spacingXXL: CGFloat { 48 }

    // MARK: - Typography

    public func font(style: TypographyStyle) -> Font {
        switch style {
        case .largeTitle: .largeTitle.bold()
        case .title: .title.bold()
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .caption: .caption
        case .price: .title2.bold()
        }
    }

    // MARK: - Corner Radii

    public var chipCornerRadius: CGFloat { 20 }
    public var buttonCornerRadius: CGFloat { 12 }
    public var cardCornerRadius: CGFloat { 16 }
    public var cardSmallCornerRadius: CGFloat { 8 }

    // MARK: - Borders

    public var borderWidth: CGFloat { 1 }

    // MARK: - Animation Durations

    public var animationFast: Double { 0.15 }
    public var animationStandard: Double { 0.30 }
    public var animationSlow: Double { 0.50 }
}
