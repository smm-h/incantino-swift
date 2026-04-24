// InMemoryConfigProvider.swift
// Testing provider -- returns hardcoded configs with no I/O.

import Foundation

/// Testing provider -- returns hardcoded configs.
/// Used in unit tests and conformance test runners.
public final class InMemoryConfigProvider: ConfigProviding, @unchecked Sendable {
    private let screens: [String: ScreenSpec]
    private let flows: [String: FlowConfig]
    private let manifest: Manifest

    public init(
        screens: [String: ScreenSpec] = [:],
        flows: [String: FlowConfig] = [:],
        features: [String: Bool]? = nil
    ) {
        self.screens = screens
        self.flows = flows
        // Build a synthetic manifest with empty hashes/URLs since
        // in-memory configs don't have content-addressed files.
        self.manifest = Manifest(
            specVersion: "1.0",
            generatedAt: nil,
            tokens: nil,
            features: features,
            scopeSchema: nil,
            screens: screens.mapValues { _ in ManifestEntry(hash: "", url: "") },
            flows: flows.mapValues { _ in ManifestEntry(hash: "", url: "") },
            sheets: nil
        )
    }

    public func loadManifest() async throws -> Manifest {
        manifest
    }

    public func loadScreen(id: String) async throws -> ScreenSpec {
        guard let screen = screens[id] else {
            throw ConfigError.notFound("Screen '\(id)' not found")
        }
        return screen
    }

    public func loadFlow(id: String) async throws -> FlowConfig {
        guard let flow = flows[id] else {
            throw ConfigError.notFound("Flow '\(id)' not found")
        }
        return flow
    }

    public func prefetch(screenIDs: [String]) async {
        // No-op: all data is already in memory.
    }
}
