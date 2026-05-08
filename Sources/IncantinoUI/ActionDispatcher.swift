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
        // 1. Guard evaluation: if guard expression is false, skip.
        if let guardExpr = spec.guard {
            if !evaluate(expression: guardExpr, scope: scope) {
                logger.debug("Action \(spec.action) blocked by guard: \(guardExpr)")
                return
            }
        }

        // 2. Confirmation dialog: if confirm is set, wait for user response.
        if let confirm = spec.confirm {
            let confirmed = await requestConfirmation(confirm)
            if !confirmed { return }
        }

        // 3. Haptic feedback.
        if let haptic = spec.haptic {
            triggerHaptic(haptic)
        }

        // 4. Dispatch through middleware chain, then handler.
        let action = spec.action
        let params = spec.params ?? [:]
        let handlerError = await runMiddlewareChain(
            index: 0, action: action, params: params, scope: scope
        )

        if let handlerError {
            logger.error("Action \(action) failed: \(handlerError.localizedDescription)")

            // 5. On error chain.
            if let onError = spec.onError {
                await dispatch(onError.value, scope: scope)
            }
        } else {
            // 6. On success chain.
            if let onSuccess = spec.onSuccess {
                await dispatch(onSuccess.value, scope: scope)
            }
        }
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
