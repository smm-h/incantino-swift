// PopupScheduler.swift
// AutoOverlay evaluation: eligibility filtering, priority sorting, cooldown/session state.

import Foundation

// MARK: - PopupStateStore

/// Persistent state store for popup scheduling decisions.
/// Implementations must be thread-safe for reads and writes.
public protocol PopupStateStore: Sendable {
    /// Total times this overlay has been shown (lifetime, across sessions).
    func getShowCount(id: String) -> Int

    /// Timestamp of last presentation, or nil if never shown.
    func getLastShown(id: String) -> Date?

    /// Increment show count and set last-shown to now.
    func recordShown(id: String)

    /// Clear all state for this overlay (testing/admin).
    func reset(id: String)
}

// MARK: - AutoOverlaySpec

/// Specification for an auto-overlay eligible for scheduled presentation.
public struct AutoOverlaySpec: Codable, Sendable {
    /// Unique identifier for this overlay.
    public let id: String

    /// Boolean expression evaluated against the current scope. Nil means always eligible.
    public let condition: String?

    /// Higher priority wins. Default 0.
    public let priority: Int

    /// Maximum total show count (lifetime). Nil means unlimited.
    public let maxShows: Int?

    /// Duration string ("24h", "7d", "30m", "60s"). Nil means no cooldown.
    public let cooldown: String?

    /// Show at most once per cold start. Nil/false means no session restriction.
    public let sessionOnce: Bool?

    public init(
        id: String,
        condition: String? = nil,
        priority: Int = 0,
        maxShows: Int? = nil,
        cooldown: String? = nil,
        sessionOnce: Bool? = nil
    ) {
        self.id = id
        self.condition = condition
        self.priority = priority
        self.maxShows = maxShows
        self.cooldown = cooldown
        self.sessionOnce = sessionOnce
    }
}

// MARK: - PopupScheduler

/// Evaluates autoOverlay eligibility and returns the overlay to present.
///
/// Algorithm (from spec/client/popup-scheduler.md):
/// 1. For each overlay, check eligibility (condition, maxShows, cooldown, sessionOnce).
/// 2. Sort eligible overlays by priority descending; ties broken by declaration order (earlier wins).
/// 3. Return the winning overlay's ID, or nil.
public final class PopupScheduler: @unchecked Sendable {
    private let store: any PopupStateStore
    private let lock = NSLock()
    private var sessionShown: Set<String> = []

    public init(store: any PopupStateStore) {
        self.store = store
    }

    /// Evaluate overlays and return the ID of the one to show, or nil.
    ///
    /// - Parameters:
    ///   - overlays: Overlay specs in declaration order.
    ///   - scope: Current scope for condition evaluation.
    ///   - now: Current time (injectable for testing). Defaults to now.
    /// - Returns: The overlay ID to present, or nil if nothing is eligible.
    public func evaluate(
        overlays: [AutoOverlaySpec],
        scope: any ScopeReading,
        now: Date = Date()
    ) -> String? {
        lock.lock()
        let currentSessionShown = sessionShown
        lock.unlock()

        // Collect eligible overlays: (priority, negated-index, id).
        var eligible: [(priority: Int, negIndex: Int, id: String)] = []

        for (index, overlay) in overlays.enumerated() {
            guard !overlay.id.isEmpty else { continue }

            if !checkEligible(overlay, sessionShown: currentSessionShown, scope: scope, now: now) {
                continue
            }

            eligible.append((priority: overlay.priority, negIndex: -index, id: overlay.id))
        }

        guard !eligible.isEmpty else { return nil }

        // Sort descending by priority, then by declaration order (earlier wins via negated index).
        eligible.sort { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            return a.negIndex > b.negIndex
        }

        return eligible[0].id
    }

    /// Record that an overlay was shown in the current session.
    /// Call this after presenting an overlay; updates the in-memory session set.
    public func markShownInSession(id: String) {
        lock.lock()
        sessionShown.insert(id)
        lock.unlock()
    }

    // MARK: - Eligibility checks

    private func checkEligible(
        _ overlay: AutoOverlaySpec,
        sessionShown: Set<String>,
        scope: any ScopeReading,
        now: Date
    ) -> Bool {
        // (a) Condition expression.
        // evaluate(expression:scope:) returns true for nil/empty (forward-compatible).
        if !Incantino.evaluate(expression: overlay.condition, scope: scope) {
            return false
        }

        // (b) maxShows check.
        if let maxShows = overlay.maxShows {
            let count = store.getShowCount(id: overlay.id)
            if count >= maxShows {
                return false
            }
        }

        // (c) Cooldown check.
        if let cooldownStr = overlay.cooldown {
            if let cooldownInterval = parseCooldown(cooldownStr) {
                if let lastShown = store.getLastShown(id: overlay.id) {
                    let elapsed = now.timeIntervalSince(lastShown)
                    if elapsed < cooldownInterval {
                        return false
                    }
                }
            }
            // Unrecognized format: cooldown check passes (forward-compatible).
        }

        // (d) sessionOnce check.
        if overlay.sessionOnce == true && sessionShown.contains(overlay.id) {
            return false
        }

        return true
    }

    // MARK: - Cooldown parsing

    /// Parse a duration string like "24h", "7d", "30m", "60s" into a TimeInterval.
    /// Returns nil for unrecognized formats (forward-compatible: overlay not blocked).
    private func parseCooldown(_ string: String) -> TimeInterval? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return nil }

        let unitChar = trimmed.last!
        let numberStr = String(trimmed.dropLast())

        guard let number = Int(numberStr), number > 0 else { return nil }

        let multiplier: TimeInterval
        switch unitChar {
        case "d": multiplier = 86400
        case "h": multiplier = 3600
        case "m": multiplier = 60
        case "s": multiplier = 1
        default: return nil
        }

        return TimeInterval(number) * multiplier
    }
}
