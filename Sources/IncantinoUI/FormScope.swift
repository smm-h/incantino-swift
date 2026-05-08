// FormScope.swift
// Observable form state container conforming to ScopeWriting.
// Creates a child scope for form inputs -- reads from parent chain,
// writes stay local. Tracks validation errors per field.

import Foundation
import Observation

// MARK: - FormScope

/// Observable scope for form data within a screen or modal.
/// Supports lexical scoping via parent, validation errors, and dirty tracking.
@Observable
public final class FormScope: ScopeWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: ScopeValue] = [:]
    private let parent: (any ScopeReading)?

    /// Validation errors keyed by binding path.
    public private(set) var errors: [String: String] = [:]

    /// Paths that have been written to at least once.
    public private(set) var dirtyPaths: Set<String> = []

    public init(parent: (any ScopeReading)? = nil) {
        self.parent = parent
    }

    // MARK: - ScopeReading

    public nonisolated func resolve(_ path: String) -> ScopeValue {
        lock.lock()
        defer { lock.unlock() }

        // Local exact match first.
        if let value = values[path] {
            return value
        }

        // Progressive prefix matching (same as DictionaryScope).
        let pathChars = Array(path)
        var dotPositions: [Int] = []
        for (i, c) in pathChars.enumerated() {
            if c == "." { dotPositions.append(i) }
        }
        for pos in dotPositions.reversed() {
            let prefix = String(pathChars[0..<pos])
            let suffix = String(pathChars[(pos + 1)...])
            if let value = values[prefix] {
                lock.unlock()
                let result = resolveProperty(suffix, on: value)
                lock.lock()
                return result
            }
        }

        // Delegate to parent.
        if let parent {
            lock.unlock()
            let result = parent.resolve(path)
            lock.lock()
            return result
        }

        return .empty
    }

    // MARK: - ScopeWriting

    public nonisolated func set(_ key: String, value: ScopeValue) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
        dirtyPaths.insert(key)
    }

    // MARK: - Validation

    /// Set a validation error for a binding path.
    public func setError(_ message: String, for path: String) {
        errors[path] = message
    }

    /// Clear validation error for a binding path.
    public func clearError(for path: String) {
        errors.removeValue(forKey: path)
    }

    /// Whether a given path has validation errors.
    public func hasError(for path: String) -> Bool {
        errors[path] != nil
    }

    /// Clear all errors.
    public func clearAllErrors() {
        errors.removeAll()
    }

    // MARK: - Convenience

    /// Read all current local values (snapshot).
    public func allValues() -> [String: ScopeValue] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    /// Whether any values have been written.
    public var isDirty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !dirtyPaths.isEmpty
    }
}
