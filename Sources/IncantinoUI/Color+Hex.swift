// Color+Hex.swift
// Hex string initializer for SwiftUI Color.

import SwiftUI

extension Color {
    /// Creates a Color from a hex string (e.g. "#FF5733" or "FF5733").
    /// Supports 6-digit (RGB) and 8-digit (ARGB) hex strings.
    /// Returns nil if the string is not a valid hex color.
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        // Parse hex value
        var rgbValue: UInt64 = 0
        guard Scanner(string: hexString).scanHexInt64(&rgbValue) else {
            return nil
        }

        let r, g, b, a: Double
        switch hexString.count {
        case 6:
            // RGB
            r = Double((rgbValue >> 16) & 0xFF) / 255.0
            g = Double((rgbValue >> 8) & 0xFF) / 255.0
            b = Double(rgbValue & 0xFF) / 255.0
            a = 1.0
        case 8:
            // AARRGGBB
            a = Double((rgbValue >> 24) & 0xFF) / 255.0
            r = Double((rgbValue >> 16) & 0xFF) / 255.0
            g = Double((rgbValue >> 8) & 0xFF) / 255.0
            b = Double(rgbValue & 0xFF) / 255.0
        default:
            return nil
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
