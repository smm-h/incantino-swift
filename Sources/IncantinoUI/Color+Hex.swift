// Color+Hex.swift
// Hex string parsing for SwiftUI Color, UIColor, and NSColor.

import SwiftUI

/// Parse a hex color string into RGBA components.
/// Supports 6-digit (RGB) and 8-digit (AARRGGBB) hex strings, with or without leading "#".
/// Returns nil for invalid input.
func parseHexComponents(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
    var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if hexString.hasPrefix("#") {
        hexString.removeFirst()
    }

    var rgbValue: UInt64 = 0
    guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
        return nil
    }

    switch hexString.count {
    case 6:
        let r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgbValue & 0xFF) / 255.0
        return (r, g, b, 1.0)
    case 8:
        let a = CGFloat((rgbValue >> 24) & 0xFF) / 255.0
        let r = CGFloat((rgbValue >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgbValue >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgbValue & 0xFF) / 255.0
        return (r, g, b, a)
    default:
        return nil
    }
}

extension Color {
    /// Creates a Color from a hex string (e.g. "#FF5733" or "FF5733").
    /// Supports 6-digit (RGB) and 8-digit (ARGB) hex strings.
    /// Returns nil if the string is not a valid hex color.
    public init?(hex: String) {
        guard let c = parseHexComponents(hex) else { return nil }
        self.init(.sRGB, red: Double(c.r), green: Double(c.g), blue: Double(c.b), opacity: Double(c.a))
    }
}
