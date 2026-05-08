// ActionDispatcher.swift
// Concrete action dispatcher with middleware chain, guard/confirm/haptic pipeline,
// and handler registry. Processes ActionSpec through the full pipeline:
// guard evaluation -> confirmation dialog -> haptic feedback -> handler dispatch -> chaining.

import SwiftUI
import os

private let logger = Logger(subsystem: "Incantino", category: "ActionDispatcher")

// MARK: - ActionDispatcher

/// Concrete implementation of ActionDispatching.
/// Processes the guard/confirm/haptic pipeline before dispatching to registered handlers.
@MainActor
public final class ActionDispatcher: ActionDispatching {
    private var handlers: [String: any ActionHandling] = [:]
    private var middleware: [any ActionMiddleware] = []

    /// Named action definitions from the current screen's `actions` map.
    /// Set by the rendering layer when a screen is loaded.
    public var screenActions: [String: NamedActionDefinition] = [:]

    /// Pending confirmation dialog state. Views observe this to show confirmation alerts.
    public var pendingConfirmation: PendingConfirmation?

    public init() {}

    // MARK: - Registration

    public func register(action: String, handler: any ActionHandling) {
        handlers[action] = handler
    }

    /// Add middleware to the dispatch chain. Middleware runs in registration order.
    public func addMiddleware(_ m: any ActionMiddleware) {
        middleware.append(m)
    }

    // MARK: - Dispatch

    public func dispatch(_ spec: ActionSpec, scope: any ScopeReading) async {
        // Step 1: Guard evaluation -- if guard expression is false, skip entirely.
        if let guardExpr = spec.guard {
            if !evaluate(expression: guardExpr, scope: scope) {
                logger.debug("Action \(spec.action) blocked by guard: \(guardExpr)")
                return
            }
        }

        // Step 2: Named action resolution -- resolve before confirm/haptic so that
        // merged confirm/onSuccess/onError from the named definition are applied.
        let resolved = resolveNamedAction(spec)
        guard let resolved else { return }

        // Step 3: Confirmation dialog -- uses the resolved (merged) confirm.
        if let confirm = resolved.confirm {
            let confirmed = await requestConfirmation(confirm)
            if !confirmed { return }
        }

        // Step 4: Haptic feedback.
        if let haptic = resolved.haptic {
            triggerHaptic(haptic)
        }

        // Step 5: Middleware chain + handler dispatch.
        let action = resolved.action
        let params = resolved.params ?? [:]
        let handlerError = await runMiddlewareChain(
            index: 0, action: action, params: params, scope: scope
        )

        // Step 6: Success/error chaining.
        if let handlerError {
            logger.error("Action \(action) failed: \(handlerError.localizedDescription)")
            if let onError = resolved.onError {
                await dispatch(onError.value, scope: scope)
            }
        } else {
            if let onSuccess = resolved.onSuccess {
                await dispatch(onSuccess.value, scope: scope)
            }
        }
    }

    // MARK: - Named Action Resolution

    /// Resolve named actions from the screen's actions map.
    /// If the action is built-in or has a registered handler, returns the spec unchanged.
    /// If it matches a screen-level named action, resolves to a `submit` action.
    /// Returns nil if the action cannot be resolved (logs a warning).
    private func resolveNamedAction(_ spec: ActionSpec) -> ActionSpec? {
        // Check built-in actions and registered handlers first.
        if SDUIAction(rawValue: spec.action) != nil || handlers[spec.action] != nil {
            return spec
        }

        // Check screen-level named actions.
        guard let definition = screenActions[spec.action] else {
            logger.warning("Unresolved action: \(spec.action) -- not built-in, registered, or in screen actions")
            return nil
        }

        // Build submit params from the named definition.
        var submitParams: JSONObject = ["endpoint": .string(definition.endpoint)]
        if let method = definition.method {
            submitParams["method"] = .string(method)
        }

        // Merge: inline spec overrides named definition defaults.
        let resolvedConfirm = spec.confirm ?? definition.confirm
        let resolvedOnSuccess = spec.onSuccess ?? definition.onSuccess
        let resolvedOnError = spec.onError ?? definition.onError

        return ActionSpec(
            action: "submit",
            params: submitParams,
            confirm: resolvedConfirm,
            haptic: spec.haptic,
            onSuccess: resolvedOnSuccess,
            onError: resolvedOnError
        )
    }

    // MARK: - Internal

    /// Run through middleware chain, then the handler. Returns the handler error (if any)
    /// so the caller can decide between onSuccess and onError chaining.
    private func runMiddlewareChain(
        index: Int, action: String, params: JSONObject, scope: any ScopeReading
    ) async -> (any Error)? {
        if index < middleware.count {
            // Capture error from downstream chain via nonisolated(unsafe) box.
            nonisolated(unsafe) var captured: (any Error)?
            let mw = middleware[index]
            await mw.intercept(action: action, params: params, scope: scope) { [self] in
                captured = await self.runMiddlewareChain(
                    index: index + 1, action: action, params: params, scope: scope
                )
            }
            return captured
        } else {
            // End of middleware chain: dispatch to handler.
            do {
                try await executeHandler(action: action, params: params, scope: scope)
                return nil
            } catch {
                return error
            }
        }
    }

    private func executeHandler(action: String, params: JSONObject, scope: any ScopeReading) async throws {
        guard let handler = handlers[action] else {
            logger.warning("No handler registered for action: \(action)")
            return
        }
        try await handler.handle(action: action, params: params, scope: scope)
    }

    private func triggerHaptic(_ type: String) {
        switch type {
        case "light": HapticManager.light()
        case "medium": HapticManager.medium()
        case "success": HapticManager.success()
        case "error": HapticManager.error()
        default: HapticManager.light()
        }
    }

    /// Request user confirmation via dialog. Returns true if confirmed.
    private func requestConfirmation(_ confirm: ActionSpec.ConfirmSpec) async -> Bool {
        await withCheckedContinuation { continuation in
            pendingConfirmation = PendingConfirmation(
                title: confirm.title,
                message: confirm.message,
                isDestructive: confirm.destructive ?? false,
                completion: { confirmed in
                    continuation.resume(returning: confirmed)
                }
            )
        }
    }
}

// MARK: - PendingConfirmation

/// Model for a pending confirmation dialog.
@MainActor
public struct PendingConfirmation {
    public let title: String
    public let message: String
    public let isDestructive: Bool
    public let completion: (Bool) -> Void
}
