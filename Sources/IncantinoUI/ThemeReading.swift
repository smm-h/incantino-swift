import SwiftUI

/// Protocol that all Incantino themes must conform to.
/// Provides 30 named tokens across 5 categories:
/// Colors (11), Spacing (6), Typography (7), Corner Radii (3), Animation Durations (3).
@MainActor
public protocol ThemeReading: AnyObject {
    // MARK: - Colors (11)

    var background: Color { get }
    var surface: Color { get }
    var surfaceElevated: Color { get }
    var accent: Color { get }
    var accentSecondary: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var separator: Color { get }
    var error: Color { get }
    var success: Color { get }
    var transit: Color { get }

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

    // MARK: - Corner Radii (3)

    var chipCornerRadius: CGFloat { get }    // 20
    var buttonCornerRadius: CGFloat { get }  // 12
    var cardCornerRadius: CGFloat { get }    // 16

    // MARK: - Animation Durations (3)

    var animationFast: Double { get }      // 0.15
    var animationStandard: Double { get }  // 0.30
    var animationSlow: Double { get }      // 0.50
}

/// Named typography styles supported by the theming system.
public enum TypographyStyle: String, CaseIterable, Sendable {
    case largeTitle, title, headline, subheadline, body, caption, price
}
