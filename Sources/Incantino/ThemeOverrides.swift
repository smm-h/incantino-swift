// ThemeOverrides.swift
// Simple theme override structure for SDUI screens.

import Foundation

/// Optional hex color overrides for theming a screen or component.
public struct ThemeOverrides: Codable, Sendable, Equatable {
    /// Background color hex string (e.g. "#FFFFFF").
    public var background: String?
    /// Surface color hex string.
    public var surface: String?
    /// Primary accent color hex string.
    public var accent: String?
    /// Secondary accent color hex string.
    public var accentSecondary: String?

    public init(
        background: String? = nil,
        surface: String? = nil,
        accent: String? = nil,
        accentSecondary: String? = nil
    ) {
        self.background = background
        self.surface = surface
        self.accent = accent
        self.accentSecondary = accentSecondary
    }
}
