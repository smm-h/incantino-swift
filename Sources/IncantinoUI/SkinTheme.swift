// SkinTheme.swift
// ThemeReading implementation driven by a SkinDefinition.
// Colors adapt to light/dark mode dynamically via platform trait collections.

import SwiftUI
import Incantino

/// Theme implementation driven by a SkinDefinition.
/// Conforms to ThemeReading so it can be used anywhere a theme is expected.
@MainActor
public final class SkinTheme: ThemeReading, Observable {
    private let skin: SkinDefinition

    public init(skin: SkinDefinition) {
        self.skin = skin
    }

    /// Load a skin from a JSON file URL.
    public convenience init(url: URL) throws {
        let data = try Data(contentsOf: url)
        let skin = try JSONDecoder().decode(SkinDefinition.self, from: data)
        self.init(skin: skin)
    }

    // MARK: - Colors (11)

    public var background: Color { adaptiveColor(from: skin.colors.background) }
    public var surface: Color { adaptiveColor(from: skin.colors.surface) }
    public var surfaceElevated: Color { adaptiveColor(from: skin.colors.surfaceElevated) }
    public var accent: Color { adaptiveColor(from: skin.colors.accent) }
    public var accentSecondary: Color { adaptiveColor(from: skin.colors.accentSecondary) }
    public var textPrimary: Color { adaptiveColor(from: skin.colors.textPrimary) }
    public var textSecondary: Color { adaptiveColor(from: skin.colors.textSecondary) }
    public var separator: Color { adaptiveColor(from: skin.colors.separator) }
    public var error: Color { adaptiveColor(from: skin.colors.error) }
    public var success: Color { adaptiveColor(from: skin.colors.success) }
    public var transit: Color { adaptiveColor(from: skin.colors.transit) }

    // MARK: - Spacing (6)

    public var spacingXS: CGFloat { CGFloat(skin.spacing.xs) }
    public var spacingSM: CGFloat { CGFloat(skin.spacing.sm) }
    public var spacingMD: CGFloat { CGFloat(skin.spacing.md) }
    public var spacingLG: CGFloat { CGFloat(skin.spacing.lg) }
    public var spacingXL: CGFloat { CGFloat(skin.spacing.xl) }
    public var spacingXXL: CGFloat { CGFloat(skin.spacing.xxl) }

    // MARK: - Typography (7)

    public func font(style: TypographyStyle) -> Font {
        let def = fontDef(for: style)
        let weight = fontWeight(def.weight)
        if let family = def.family {
            return .custom(family, size: CGFloat(def.size)).weight(weight)
        }
        return .system(size: CGFloat(def.size)).weight(weight)
    }

    // MARK: - Corner Radii (3)

    public var chipCornerRadius: CGFloat { CGFloat(skin.cornerRadii.chip) }
    public var buttonCornerRadius: CGFloat { CGFloat(skin.cornerRadii.button) }
    public var cardCornerRadius: CGFloat { CGFloat(skin.cornerRadii.card) }

    // MARK: - Animation Durations (3)

    public var animationFast: Double { skin.animation.fast }
    public var animationStandard: Double { skin.animation.standard }
    public var animationSlow: Double { skin.animation.slow }

    // MARK: - Private Helpers

    /// Creates a Color that dynamically resolves to the correct hex value
    /// based on the current appearance (light/dark mode).
    private func adaptiveColor(from pair: SkinDefinition.ColorPair) -> Color {
        #if canImport(UIKit)
        let uiColor = UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? pair.dark : pair.light
            return UIColor(hex: hex) ?? .clear
        }
        return Color(uiColor)
        #elseif canImport(AppKit)
        let nsColor = NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? pair.dark : pair.light
            return NSColor(hex: hex) ?? .clear
        }
        return Color(nsColor)
        #else
        // Fallback: use light variant
        return Color(hex: pair.light) ?? .clear
        #endif
    }

    private func fontDef(for style: TypographyStyle) -> SkinDefinition.Typography.FontDef {
        switch style {
        case .largeTitle: skin.typography.largeTitle
        case .title: skin.typography.title
        case .headline: skin.typography.headline
        case .subheadline: skin.typography.subheadline
        case .body: skin.typography.body
        case .caption: skin.typography.caption
        case .price: skin.typography.price
        }
    }

    private func fontWeight(_ name: String) -> Font.Weight {
        switch name.lowercased() {
        case "bold": .bold
        case "semibold": .semibold
        case "medium": .medium
        case "light": .light
        case "thin": .thin
        case "ultralight": .ultraLight
        case "heavy": .heavy
        case "black": .black
        default: .regular
        }
    }
}

// MARK: - Platform Color Hex Extensions

#if canImport(UIKit)
import UIKit

extension UIColor {
    /// Creates a UIColor from a hex string. Returns nil for invalid input.
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
            return nil
        }

        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6:
            r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            b = CGFloat(rgbValue & 0xFF) / 255.0
            a = 1.0
        case 8:
            a = CGFloat((rgbValue >> 24) & 0xFF) / 255.0
            r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            b = CGFloat(rgbValue & 0xFF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

extension NSColor {
    /// Creates an NSColor from a hex string. Returns nil for invalid input.
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
            return nil
        }

        let r, g, b, a: CGFloat
        switch hexString.count {
        case 6:
            r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            b = CGFloat(rgbValue & 0xFF) / 255.0
            a = 1.0
        case 8:
            a = CGFloat((rgbValue >> 24) & 0xFF) / 255.0
            r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
            g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
            b = CGFloat(rgbValue & 0xFF) / 255.0
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
#endif
