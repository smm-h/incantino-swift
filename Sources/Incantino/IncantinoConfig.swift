// IncantinoConfig.swift
// The engine's top-level config model. No app-specific domain fields.

import Foundation

/// The engine's top-level config. Decoded from JSON or YAML.
/// Contains screens, flows, sheets, feature flags, theme overrides,
/// scope schema declarations, and design tokens.
public struct IncantinoConfig: Codable, Sendable {
    public let configVersion: Int?
    public let screens: [String: ScreenSpec]?
    public let flows: [String: FlowConfig]?
    public let sheets: [String: String]?
    public let features: [String: Bool]?
    public let themeOverrides: ThemeOverrides?
    public let scopeSchema: [ScopePathDeclaration]?
    public let tokens: JSONObject?

    public init(
        configVersion: Int? = nil,
        screens: [String: ScreenSpec]? = nil,
        flows: [String: FlowConfig]? = nil,
        sheets: [String: String]? = nil,
        features: [String: Bool]? = nil,
        themeOverrides: ThemeOverrides? = nil,
        scopeSchema: [ScopePathDeclaration]? = nil,
        tokens: JSONObject? = nil
    ) {
        self.configVersion = configVersion
        self.screens = screens
        self.flows = flows
        self.sheets = sheets
        self.features = features
        self.themeOverrides = themeOverrides
        self.scopeSchema = scopeSchema
        self.tokens = tokens
    }

    /// An empty config with all fields nil.
    public static let empty = IncantinoConfig()
}
