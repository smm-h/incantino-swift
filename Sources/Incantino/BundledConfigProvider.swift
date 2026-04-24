// BundledConfigProvider.swift
// Wraps a FileConfigProvider (bundle) and ManifestConfigProvider (live).
// Launches instantly from bundle, background-refreshes from live.
// Implements the bundled baseline pattern from the spec.

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Wraps a bundle provider (reads from app bundle at build time) and a live
/// provider (fetches updates from CDN). The app launches instantly from the
/// bundle; a background refresh detects stale screens by comparing content
/// hashes. Stale screens are lazy-refreshed on navigation.
public final class BundledConfigProvider: ConfigProviding, @unchecked Sendable {
    /// Reads configs from the app bundle (FileConfigProvider).
    private let bundle: ConfigProviding
    /// Fetches live configs from CDN (ManifestConfigProvider).
    private let live: ConfigProviding
    /// Screen IDs whose content hash differs between bundle and live manifest.
    private var staleScreens: Set<String> = []
    /// Flow IDs whose content hash differs between bundle and live manifest.
    private var staleFlows: Set<String> = []
    /// Screens fetched from the live provider (overrides for stale bundled screens).
    private var liveScreenCache: [String: ScreenSpec] = [:]
    /// Flows fetched from the live provider (overrides for stale bundled flows).
    private var liveFlowCache: [String: FlowConfig] = [:]
    /// The live manifest, once fetched.
    private var liveManifest: Manifest?
    private let lock = NSLock()

    public init(bundleDirectory: URL, manifestURL: URL, session: URLSession = .shared) {
        self.bundle = FileConfigProvider(directory: bundleDirectory)
        self.live = ManifestConfigProvider(manifestURL: manifestURL, session: session)
    }

    /// Internal initializer for testing -- accepts any ConfigProviding pair.
    init(bundle: ConfigProviding, live: ConfigProviding) {
        self.bundle = bundle
        self.live = live
    }

    public func loadManifest() async throws -> Manifest {
        let bundledManifest = try await bundle.loadManifest()

        // Version gate: check if the bundled config is compatible with this engine.
        let compatibility = VersionGate.check(specVersion: bundledManifest.specVersion)
        if case .updateRequired = compatibility {
            throw ConfigError.parseError(
                "Config specVersion \(bundledManifest.specVersion ?? "nil") exceeds engine max \(VersionGate.maxSupportedVersion). App update required."
            )
        }

        // Kick off a non-blocking background refresh.
        // This Task is fire-and-forget: it updates staleScreens/staleFlows
        // so subsequent loadScreen/loadFlow calls can serve fresh data.
        Task { [weak self] in
            await self?.backgroundRefresh(bundledManifest: bundledManifest)
        }

        return bundledManifest
    }

    public func loadScreen(id: String) async throws -> ScreenSpec {
        // If we already fetched a live version, return it.
        if let cached = lock.withLock({ liveScreenCache[id] }) {
            return cached
        }

        // If the screen is stale, try the live provider first.
        if lock.withLock({ staleScreens.contains(id) }) {
            if let screen = try? await live.loadScreen(id: id) {
                lock.withLock {
                    liveScreenCache[id] = screen
                    staleScreens.remove(id)
                }
                return screen
            }
            // Live fetch failed -- fall through to bundle (graceful degradation).
        }

        // Serve from bundle.
        return try await bundle.loadScreen(id: id)
    }

    public func loadFlow(id: String) async throws -> FlowConfig {
        // If we already fetched a live version, return it.
        if let cached = lock.withLock({ liveFlowCache[id] }) {
            return cached
        }

        // If the flow is stale, try the live provider first.
        if lock.withLock({ staleFlows.contains(id) }) {
            if let flow = try? await live.loadFlow(id: id) {
                lock.withLock {
                    liveFlowCache[id] = flow
                    staleFlows.remove(id)
                }
                return flow
            }
            // Live fetch failed -- fall through to bundle (graceful degradation).
        }

        // Serve from bundle.
        return try await bundle.loadFlow(id: id)
    }

    public func prefetch(screenIDs: [String]) async {
        // Prefetch stale screens from the live provider.
        // Non-stale screens are already in the bundle, no prefetch needed.
        let staleIDs = lock.withLock {
            screenIDs.filter { staleScreens.contains($0) }
        }

        for id in staleIDs {
            if let screen = try? await live.loadScreen(id: id) {
                lock.withLock {
                    liveScreenCache[id] = screen
                    staleScreens.remove(id)
                }
            }
        }
    }

    // MARK: - Background refresh

    /// Fetch the live manifest and compare content hashes against the bundle.
    /// Marks screens/flows with differing hashes as stale for lazy refresh.
    private func backgroundRefresh(bundledManifest: Manifest) async {
        guard let liveManifest = try? await live.loadManifest() else {
            return // Network unavailable -- continue with bundle silently.
        }

        // Version gate on the live manifest too.
        let compatibility = VersionGate.check(specVersion: liveManifest.specVersion)
        if case .updateRequired = compatibility {
            // Live config is too new for this engine. Stick with bundle.
            return
        }

        // Compare screen hashes.
        var newStaleScreens: Set<String> = []
        if let liveScreens = liveManifest.screens {
            let bundledScreens = bundledManifest.screens ?? [:]
            for (id, liveEntry) in liveScreens {
                let bundledHash = bundledScreens[id]?.hash
                // Stale if: hash differs, or screen is new (not in bundle).
                if bundledHash != liveEntry.hash {
                    newStaleScreens.insert(id)
                }
            }
        }

        // Compare flow hashes.
        var newStaleFlows: Set<String> = []
        if let liveFlows = liveManifest.flows {
            let bundledFlows = bundledManifest.flows ?? [:]
            for (id, liveEntry) in liveFlows {
                let bundledHash = bundledFlows[id]?.hash
                if bundledHash != liveEntry.hash {
                    newStaleFlows.insert(id)
                }
            }
        }

        lock.withLock {
            self.staleScreens = newStaleScreens
            self.staleFlows = newStaleFlows
            self.liveManifest = liveManifest
        }
    }
}
