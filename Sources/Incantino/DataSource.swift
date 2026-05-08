// DataSource.swift
// Data source loading, resolution, and screen data management.

import Foundation

// MARK: - LoadState

/// The loading state of a data source.
public enum LoadState: Sendable {
    case loading
    case loaded(JSONValue)
    case empty
    case error(String)
}

// MARK: - DataSourceResolving

/// Protocol for resolving data sources by identifier.
@MainActor
public protocol DataSourceResolving {
    /// Fetch data for the given data source spec.
    func fetch(spec: DataSourceSpec) async -> LoadState

    /// Re-fetch data for the given data source spec.
    func refresh(spec: DataSourceSpec) async -> LoadState
}

// MARK: - NoOpDataSourceResolver

/// A resolver that always returns empty. Used as a default/placeholder.
@MainActor
public final class NoOpDataSourceResolver: DataSourceResolving {
    public init() {}

    public func fetch(spec: DataSourceSpec) async -> LoadState {
        .empty
    }

    public func refresh(spec: DataSourceSpec) async -> LoadState {
        .empty
    }
}

// MARK: - ScreenDataLoader

/// Manages data sources for a screen.
/// Fetches all sources concurrently and builds a DictionaryScope from the results.
@MainActor
public final class ScreenDataLoader {
    private let resolver: any DataSourceResolving
    private var states: [String: LoadState] = [:]

    public init(resolver: any DataSourceResolving) {
        self.resolver = resolver
    }

    /// Fetch all data sources and build a scope.
    /// Data source names (the dictionary keys) are used as keys under the `$data` namespace.
    /// Also sets metadata keys like `$data.<name>.$loading`, `$data.<name>.$error`.
    ///
    /// Sources are fetched concurrently by spawning individual tasks and
    /// collecting their results. Each task hops back to the main actor to
    /// call the resolver (which is @MainActor-isolated).
    public func fetchAll(sources: [String: DataSourceSpec], into scope: DictionaryScope) async {
        // Spawn one Task per source. Each Task inherits @MainActor isolation
        // because ScreenDataLoader is @MainActor, so the resolver call is safe.
        var tasks: [String: Task<LoadState, Never>] = [:]
        for (name, spec) in sources {
            tasks[name] = Task {
                await resolver.fetch(spec: spec)
            }
        }

        // Collect results.
        for (name, task) in tasks {
            let state = await task.value
            applyState(state, forSource: name, into: scope)
        }
    }

    /// Refresh a single data source and update the scope.
    public func refresh(name: String, spec: DataSourceSpec, into scope: DictionaryScope) async {
        let state = await resolver.refresh(spec: spec)
        applyState(state, forSource: name, into: scope)
    }

    /// Get the current load state for a source.
    public func state(for source: String) -> LoadState {
        states[source] ?? .empty
    }

    // MARK: - Internal

    /// Write a load state into the scope under the `$data` namespace.
    private func applyState(_ state: LoadState, forSource source: String, into scope: DictionaryScope) {
        states[source] = state
        let dataKey = "$data.\(source)"

        switch state {
        case .loading:
            scope.set(dataKey, value: .empty)
            scope.set("\(dataKey).$loading", value: .bool(true))
            scope.set("\(dataKey).$error", value: .empty)
        case .loaded(let value):
            scope.set(dataKey, value: .json(value))
            scope.set("\(dataKey).$loading", value: .bool(false))
            scope.set("\(dataKey).$error", value: .empty)
        case .empty:
            scope.set(dataKey, value: .empty)
            scope.set("\(dataKey).$loading", value: .bool(false))
            scope.set("\(dataKey).$error", value: .empty)
        case .error(let message):
            scope.set(dataKey, value: .empty)
            scope.set("\(dataKey).$loading", value: .bool(false))
            scope.set("\(dataKey).$error", value: .text(message))
        }
    }
}
