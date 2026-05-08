import SwiftUI

/// Protocol that all Incantino themes must conform to.
/// Provides 42 named tokens across 6 categories:
/// Colors (21), Spacing (6), Typography (7), Corner Radii (4), Borders (1), Animation Durations (3).
@MainActor
public protocol ThemeReading: AnyObject {
    // MARK: - Colors (21)

    var background: Color { get }
    var surface: Color { get }
    var surfaceElevated: Color { get }
    var accent: Color { get }
    var accentSecondary: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textTertiary: Color { get }
    var separator: Color { get }
    var error: Color { get }
    var success: Color { get }
    var transit: Color { get }
    var warning: Color { get }
    var cardFill: Color { get }
    var badgeBackground: Color { get }
    var badgeText: Color { get }
    var brandGradientStart: Color { get }
    var brandGradientEnd: Color { get }
    var completedStep: Color { get }
    var overlayButtonBackground: Color { get }
    var borderColor: Color { get }

    // MARK: - Spacing (6)

    var spacingXS: CGFloat { get }   // 4
    var spacingSM: CGFloat { get }   // 8
    var spacingMD: CGFloat { get }   // 16
    var spacingLG: CGFloat { get }   // 24
    var spacingXL: CGFloat { get }   // 32
    var spacingXXL: CGFloat { get }  // 48

    // MARK: - Typography (7)

    /// Returns the font for the given typography style.
    func font(style: TypographyStyle) -> Font

    // MARK: - Corner Radii (4)

    var chipCornerRadius: CGFloat { get }        // 20
    var buttonCornerRadius: CGFloat { get }      // 12
    var cardCornerRadius: CGFloat { get }        // 16
    var cardSmallCornerRadius: CGFloat { get }   // 8

    // MARK: - Borders (1)

    var borderWidth: CGFloat { get }  // 1

    // MARK: - Animation Durations (3)

    var animationFast: Double { get }      // 0.15
    var animationStandard: Double { get }  // 0.30
    var animationSlow: Double { get }      // 0.50
}

// MARK: - Protocol Extension Defaults (new tokens)

/// Defaults for tokens added after the initial 30, so existing conformers don't break.
extension ThemeReading {
    public var textTertiary: Color { .secondary }
    public var warning: Color { .orange }
    public var cardFill: Color { surface }
    public var badgeBackground: Color { .red }
    public var badgeText: Color { .white }
    public var brandGradientStart: Color { accent }
    public var brandGradientEnd: Color { accentSecondary }
    public var completedStep: Color { .green }
    public var overlayButtonBackground: Color { Color.black.opacity(0.8) }
    public var borderColor: Color { separator }

    public var cardSmallCornerRadius: CGFloat { 8 }
    public var borderWidth: CGFloat { 1 }
}

/// Named typography styles supported by the theming system.
public enum TypographyStyle: String, CaseIterable, Sendable {
    case largeTitle, title, headline, subheadline, body, caption, price
}
