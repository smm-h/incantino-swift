// ActionDispatching.swift
// Action dispatch pipeline protocols and no-op implementation.

import Foundation

// MARK: - ActionDispatching

/// Protocol for dispatching SDUI actions through the pipeline.
@MainActor
public protocol ActionDispatching: AnyObject {
    /// Dispatch an action with parameters and scope context.
    func dispatch(action: String, params: JSONObject, scope: any ScopeReading) async

    /// Register a handler for an action type.
    func register(action: String, handler: any ActionHandling)
}

// MARK: - ActionHandling

/// Protocol for handling a specific action type.
@MainActor
public protocol ActionHandling {
    /// Handle an action invocation. Throws on failure.
    func handle(action: String, params: JSONObject, scope: any ScopeReading) async throws
}

// MARK: - ActionMiddleware

/// Protocol for intercepting actions in the dispatch pipeline.
@MainActor
public protocol ActionMiddleware {
    /// Intercept an action. Call `next()` to continue the chain.
    func intercept(
        action: String,
        params: JSONObject,
        scope: any ScopeReading,
        next: @Sendable () async -> Void
    ) async
}

// MARK: - NoOpDispatcher

/// A dispatcher that does nothing. Used as a default/placeholder.
@MainActor
public final class NoOpDispatcher: ActionDispatching {
    public init() {}

    public func dispatch(action: String, params: JSONObject, scope: any ScopeReading) async {
        // No-op.
    }

    public func register(action: String, handler: any ActionHandling) {
        // No-op.
    }
}
