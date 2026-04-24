// ConfigProviding.swift
// Protocol for loading Incantino configs from any source.
// The engine never knows where configs come from -- it always goes through a provider.

import Foundation

// MARK: - ConfigProviding protocol

/// Protocol for loading Incantino configs from any source.
/// The engine never knows where configs come from -- it always goes through a provider.
public protocol ConfigProviding: Sendable {
    /// Load the manifest (list of screens with content hashes, global config).
    func loadManifest() async throws -> Manifest

    /// Load a single screen by ID.
    func loadScreen(id: String) async throws -> ScreenSpec

    /// Load a single flow by ID.
    func loadFlow(id: String) async throws -> FlowConfig

    /// Background-load screens (best-effort, no throw).
    func prefetch(screenIDs: [String]) async
}

// MARK: - Manifest

/// The manifest describes the full config for production delivery.
/// Contains screen/flow entries with content hashes for incremental updates,
/// plus global config (tokens, features, scope schema, sheets).
public struct Manifest: Codable, Sendable {
    public let specVersion: String?
    public let generatedAt: String?
    public let tokens: JSONObject?
    public let features: [String: Bool]?
    public let scopeSchema: [ScopePathDeclaration]?
    public let screens: [String: ManifestEntry]?
    public let flows: [String: ManifestEntry]?
    /// Sheet ID -> screen ID mapping.
    public let sheets: [String: String]?

    public init(
        specVersion: String? = nil,
        generatedAt: String? = nil,
        tokens: JSONObject? = nil,
        features: [String: Bool]? = nil,
        scopeSchema: [ScopePathDeclaration]? = nil,
        screens: [String: ManifestEntry]? = nil,
        flows: [String: ManifestEntry]? = nil,
        sheets: [String: String]? = nil
    ) {
        self.specVersion = specVersion
        self.generatedAt = generatedAt
        self.tokens = tokens
        self.features = features
        self.scopeSchema = scopeSchema
        self.screens = screens
        self.flows = flows
        self.sheets = sheets
    }
}

// MARK: - ManifestEntry

/// A single entry in the manifest -- references a content-addressed file.
public struct ManifestEntry: Codable, Sendable {
    public let hash: String
    public let url: String

    public init(hash: String, url: String) {
        self.hash = hash
        self.url = url
    }
}

// MARK: - ConfigError

/// Error categories for provider failures.
/// These are for developer use (logging, analytics, debugging).
/// The engine falls back to bundled/cached data on any error.
public enum ConfigError: Error, Sendable {
    case networkError(String)
    case parseError(String)
    case notFound(String)
    case timeout
    case unknown(String)
}

// MARK: - VersionGate

/// Version gate utilities for checking config specVersion against engine capabilities.
/// The engine checks specVersion on every config load (bundled or live).
public enum VersionGate {
    /// The engine's supported spec version range.
    /// - maxSupported: highest specVersion the engine can render correctly
    /// - minSupported: lowest specVersion the engine can attempt (with graceful degradation)
    public static let maxSupportedVersion = "1.0"
    public static let minSupportedVersion = "1.0"

    /// Result of a version compatibility check.
    public enum Compatibility: Sendable {
        /// Config is within the supported range.
        case compatible
        /// Config specVersion exceeds engine's max -- show "update required" screen.
        case updateRequired(configVersion: String, maxSupported: String)
        /// Config specVersion is below engine's min -- attempt graceful degradation.
        case degraded(configVersion: String, minSupported: String)
    }

    /// Check a config's specVersion against the engine's supported range.
    /// Returns `.compatible` if specVersion is nil (assumed compatible).
    public static func check(specVersion: String?) -> Compatibility {
        guard let version = specVersion else { return .compatible }

        if compare(version, isGreaterThan: maxSupportedVersion) {
            return .updateRequired(configVersion: version, maxSupported: maxSupportedVersion)
        }
        if compare(version, isLessThan: minSupportedVersion) {
            return .degraded(configVersion: version, minSupported: minSupportedVersion)
        }
        return .compatible
    }

    /// Simple semver-like comparison (dot-separated numeric components).
    /// Returns true if `a` is greater than `b`.
    private static func compare(_ a: String, isGreaterThan b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(aParts.count, bParts.count)
        for i in 0..<maxLen {
            let aVal = i < aParts.count ? aParts[i] : 0
            let bVal = i < bParts.count ? bParts[i] : 0
            if aVal > bVal { return true }
            if aVal < bVal { return false }
        }
        return false
    }

    /// Returns true if `a` is less than `b`.
    private static func compare(_ a: String, isLessThan b: String) -> Bool {
        return compare(b, isGreaterThan: a)
    }
}
