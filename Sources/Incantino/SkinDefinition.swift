// SkinDefinition.swift
// JSON/YAML-decodable struct containing all theme token values.
// This is what a skin author creates -- a complete description of a visual identity.
// Foundation-only (no SwiftUI dependency) so it can live in the Incantino core target.

import Foundation

/// A complete skin definition, loadable from JSON or YAML.
/// Each field maps directly to a ThemeReading token.
public struct SkinDefinition: Codable, Sendable {
    public let name: String

    public struct ColorPair: Codable, Sendable {
        /// Hex color string for light mode (e.g. "#FFFFFF").
        public let light: String
        /// Hex color string for dark mode (e.g. "#1A1A1A").
        public let dark: String

        public init(light: String, dark: String) {
            self.light = light
            self.dark = dark
        }
    }

    // MARK: - Colors (11)

    public let colors: Colors

    public struct Colors: Codable, Sendable {
        public let background: ColorPair
        public let surface: ColorPair
        public let surfaceElevated: ColorPair
        public let accent: ColorPair
        public let accentSecondary: ColorPair
        public let textPrimary: ColorPair
        public let textSecondary: ColorPair
        public let separator: ColorPair
        public let error: ColorPair
        public let success: ColorPair
        public let transit: ColorPair
    }

    // MARK: - Spacing (6)

    public let spacing: Spacing

    public struct Spacing: Codable, Sendable {
        public let xs: Double
        public let sm: Double
        public let md: Double
        public let lg: Double
        public let xl: Double
        public let xxl: Double
    }

    // MARK: - Typography (7)

    public let typography: Typography

    public struct Typography: Codable, Sendable {
        public struct FontDef: Codable, Sendable {
            /// Font family name, or nil for the system font.
            public let family: String?
            /// Weight name: "regular", "medium", "semibold", "bold".
            public let weight: String
            /// Point size.
            public let size: Double

            public init(family: String? = nil, weight: String, size: Double) {
                self.family = family
                self.weight = weight
                self.size = size
            }
        }

        public let largeTitle: FontDef
        public let title: FontDef
        public let headline: FontDef
        public let subheadline: FontDef
        public let body: FontDef
        public let caption: FontDef
        public let price: FontDef
    }

    // MARK: - Corner Radii (3)

    public let cornerRadii: CornerRadii

    public struct CornerRadii: Codable, Sendable {
        public let chip: Double
        public let button: Double
        public let card: Double
    }

    // MARK: - Animation Durations (3)

    public let animation: AnimationDurations

    public struct AnimationDurations: Codable, Sendable {
        public let fast: Double
        public let standard: Double
        public let slow: Double
    }
}
