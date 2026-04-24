// ManifestConfigProvider.swift
// Production provider -- fetches configs from a URL using conditional ETag requests.
// Lazy-loads individual screens/flows on demand and caches them in memory.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Production provider -- fetches from a CDN URL using conditional ETag requests.
/// Supports efficient cache invalidation via `If-None-Match` / `304 Not Modified`.
/// Lazy-loads individual screens and flows from content-addressed URLs in the manifest.
public final class ManifestConfigProvider: ConfigProviding, @unchecked Sendable {
    private let manifestURL: URL
    private let session: URLSession
    private var cachedManifest: Manifest?
    private var cachedScreens: [String: ScreenSpec] = [:]
    private var cachedFlows: [String: FlowConfig] = [:]
    private var etag: String?
    private let lock = NSLock()

    public init(manifestURL: URL, session: URLSession = .shared) {
        self.manifestURL = manifestURL
        self.session = session
    }

    public func loadManifest() async throws -> Manifest {
        var request = URLRequest(url: manifestURL)
        // Use conditional fetch if we have a cached ETag.
        if let etag = lock.withLock({ self.etag }) {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ConfigError.networkError("Failed to fetch manifest: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw ConfigError.unknown("Non-HTTP response")
        }

        // 304 Not Modified -- return cached manifest.
        if http.statusCode == 304 {
            if let cached = lock.withLock({ self.cachedManifest }) {
                return cached
            }
            // No cached manifest despite 304 -- should not happen, but recover.
            throw ConfigError.unknown("Received 304 but no cached manifest available")
        }

        guard http.statusCode == 200 else {
            throw ConfigError.networkError("HTTP \(http.statusCode)")
        }

        let manifest: Manifest
        do {
            manifest = try JSONDecoder().decode(Manifest.self, from: data)
        } catch {
            throw ConfigError.parseError("Failed to decode manifest: \(error)")
        }

        lock.withLock {
            cachedManifest = manifest
            etag = http.value(forHTTPHeaderField: "ETag")
        }
        return manifest
    }

    public func loadScreen(id: String) async throws -> ScreenSpec {
        // Return cached screen if available.
        if let cached = lock.withLock({ cachedScreens[id] }) {
            return cached
        }

        let entry = try manifestEntry(forScreen: id)
        let data = try await fetchResource(at: entry.url, entityType: "Screen", id: id)

        let screen: ScreenSpec
        do {
            screen = try JSONDecoder().decode(ScreenSpec.self, from: data)
        } catch {
            throw ConfigError.parseError("Failed to decode screen '\(id)': \(error)")
        }

        lock.withLock { cachedScreens[id] = screen }
        return screen
    }

    public func loadFlow(id: String) async throws -> FlowConfig {
        // Return cached flow if available.
        if let cached = lock.withLock({ cachedFlows[id] }) {
            return cached
        }

        let entry = try manifestEntry(forFlow: id)
        let data = try await fetchResource(at: entry.url, entityType: "Flow", id: id)

        let flow: FlowConfig
        do {
            flow = try JSONDecoder().decode(FlowConfig.self, from: data)
        } catch {
            throw ConfigError.parseError("Failed to decode flow '\(id)': \(error)")
        }

        lock.withLock { cachedFlows[id] = flow }
        return flow
    }

    public func prefetch(screenIDs: [String]) async {
        // Best-effort parallel prefetch. Errors are silently swallowed.
        await withTaskGroup(of: Void.self) { group in
            for id in screenIDs {
                // Skip already-cached screens.
                if lock.withLock({ cachedScreens[id] }) != nil { continue }
                group.addTask {
                    _ = try? await self.loadScreen(id: id)
                }
            }
        }
    }

    // MARK: - Private helpers

    /// Look up a screen entry in the cached manifest.
    private func manifestEntry(forScreen id: String) throws -> ManifestEntry {
        guard let manifest = lock.withLock({ cachedManifest }),
              let entry = manifest.screens?[id] else {
            throw ConfigError.notFound("Screen '\(id)' not found in manifest")
        }
        return entry
    }

    /// Look up a flow entry in the cached manifest.
    private func manifestEntry(forFlow id: String) throws -> ManifestEntry {
        guard let manifest = lock.withLock({ cachedManifest }),
              let entry = manifest.flows?[id] else {
            throw ConfigError.notFound("Flow '\(id)' not found in manifest")
        }
        return entry
    }

    /// Fetch raw data from a resource URL (relative to the manifest base URL).
    private func fetchResource(at urlString: String, entityType: String, id: String) async throws -> Data {
        // Resolve URL relative to the manifest's base path.
        let url: URL
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            guard let absolute = URL(string: urlString) else {
                throw ConfigError.notFound("\(entityType) '\(id)' has invalid URL: \(urlString)")
            }
            url = absolute
        } else {
            url = manifestURL.deletingLastPathComponent().appendingPathComponent(urlString)
        }

        let data: Data
        do {
            (data, _) = try await session.data(from: url)
        } catch {
            throw ConfigError.networkError("Failed to fetch \(entityType) '\(id)': \(error.localizedDescription)")
        }
        return data
    }
}
