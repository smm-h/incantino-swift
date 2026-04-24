// FileConfigProvider.swift
// Development provider -- reads YAML files from a local directory.
// Directory structure: screens/*.yaml, flows/*.yaml, tokens.yaml, features.yaml, scope-schema.yaml.

import Foundation
import Yams

/// Development provider -- reads YAML files from a local directory.
/// No network, no persistent caching -- reads files directly from disk.
/// Used by `v incantino serve` and CLI tooling for offline rendering.
public final class FileConfigProvider: ConfigProviding, @unchecked Sendable {
    private let directory: URL
    private var cache: [String: Any] = [:]
    private let lock = NSLock()

    public init(directory: URL) {
        self.directory = directory
    }

    public func loadManifest() async throws -> Manifest {
        // Read global config files (all optional).
        let tokens = try? readYAML(JSONObject.self, from: "tokens.yaml")
        let features = try? readYAML([String: Bool].self, from: "features.yaml")
        let scopeSchema = try? readYAML([ScopePathDeclaration].self, from: "scope-schema.yaml")

        // Scan screens/ directory for .yaml files.
        let screenEntries = scanDirectory(subdirectory: "screens")

        // Scan flows/ directory for .yaml files.
        let flowEntries = scanDirectory(subdirectory: "flows")

        return Manifest(
            specVersion: "1.0",
            generatedAt: nil,
            tokens: tokens,
            features: features,
            scopeSchema: scopeSchema,
            screens: screenEntries,
            flows: flowEntries,
            sheets: nil
        )
    }

    public func loadScreen(id: String) async throws -> ScreenSpec {
        // Check cache first.
        if let cached: ScreenSpec = cachedValue(forKey: "screen:\(id)") {
            return cached
        }

        let path = directory.appendingPathComponent("screens/\(id).yaml")
        let data = try readFileData(at: path, entityType: "Screen", id: id)
        let decoder = YAMLDecoder()
        do {
            let screen = try decoder.decode(ScreenSpec.self, from: data)
            setCachedValue(screen, forKey: "screen:\(id)")
            return screen
        } catch {
            throw ConfigError.parseError("Failed to decode screen '\(id)': \(error)")
        }
    }

    public func loadFlow(id: String) async throws -> FlowConfig {
        // Check cache first.
        if let cached: FlowConfig = cachedValue(forKey: "flow:\(id)") {
            return cached
        }

        let path = directory.appendingPathComponent("flows/\(id).yaml")
        let data = try readFileData(at: path, entityType: "Flow", id: id)
        let decoder = YAMLDecoder()
        do {
            let flow = try decoder.decode(FlowConfig.self, from: data)
            setCachedValue(flow, forKey: "flow:\(id)")
            return flow
        } catch {
            throw ConfigError.parseError("Failed to decode flow '\(id)': \(error)")
        }
    }

    public func prefetch(screenIDs: [String]) async {
        // Pre-read files into cache. Best-effort, errors silently ignored.
        for id in screenIDs {
            _ = try? await loadScreen(id: id)
        }
    }

    // MARK: - Private helpers

    /// Read a file and return its Data, throwing ConfigError on failure.
    private func readFileData(at path: URL, entityType: String, id: String) throws -> Data {
        do {
            return try Data(contentsOf: path)
        } catch {
            throw ConfigError.notFound("\(entityType) '\(id)' not found at \(path.path)")
        }
    }

    /// Decode a YAML file at a relative path from the config directory.
    private func readYAML<T: Decodable>(_ type: T.Type, from relativePath: String) throws -> T {
        let path = directory.appendingPathComponent(relativePath)
        let data = try Data(contentsOf: path)
        let decoder = YAMLDecoder()
        return try decoder.decode(type, from: data)
    }

    /// Scan a subdirectory for .yaml files and build ManifestEntry map.
    /// Keys are filenames without extension. Entries have empty hashes
    /// (file provider doesn't do content addressing) and file:// URLs.
    private func scanDirectory(subdirectory: String) -> [String: ManifestEntry] {
        let dirURL = directory.appendingPathComponent(subdirectory)
        var entries: [String: ManifestEntry] = [:]

        guard let enumerator = FileManager.default.enumerator(
            at: dirURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else {
            return entries
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "yaml" || fileURL.pathExtension == "yml" else {
                continue
            }
            let id = fileURL.deletingPathExtension().lastPathComponent
            entries[id] = ManifestEntry(hash: "", url: fileURL.path)
        }

        return entries
    }

    /// Type-safe cache read under lock.
    private func cachedValue<T>(forKey key: String) -> T? {
        lock.withLock { cache[key] as? T }
    }

    /// Cache write under lock.
    private func setCachedValue(_ value: Any, forKey key: String) {
        lock.withLock { cache[key] = value }
    }
}
