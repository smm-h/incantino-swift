// FormScope.swift
// Observable form state container conforming to ScopeWriting.
// Creates a child scope for form inputs -- reads from parent chain,
// writes stay local. Tracks validation errors, dirty paths, and
// supports form submission (toJSON), validation, and reset.

import Foundation
import Observation

// MARK: - FormScope

/// Observable scope for form data within a screen or modal.
/// Supports lexical scoping via parent, validation errors, dirty tracking,
/// expression-based field validation, and JSON serialization for submission.
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
        // Clear validation error when value changes.
        errors.removeValue(forKey: key)
    }

    // MARK: - Validation errors

    /// Set a validation error for a binding path.
    public func setError(_ message: String, for path: String) {
        errors[path] = message
    }

    /// Set a validation error (Lisa-compatible parameter order).
    public func setError(_ key: String, message: String) {
        errors[key] = message
    }

    /// Get the validation error for a field, if any.
    public func error(for key: String) -> String? {
        errors[key]
    }

    /// Clear validation error for a binding path.
    public func clearError(for path: String) {
        errors.removeValue(forKey: path)
    }

    /// Whether a given path has validation errors.
    public func hasError(for path: String) -> Bool {
        errors[path] != nil
    }

    /// Whether any validation errors exist.
    public var hasErrors: Bool { !errors.isEmpty }

    /// Clear all errors.
    public func clearAllErrors() {
        errors.removeAll()
    }

    // MARK: - Validation

    /// Validate all rules on a set of section specs. Returns true if all pass.
    /// Uses Incantino's `evaluate(expression:scope:)` for each rule's condition.
    public func validate(sections: [SectionSpec]) -> Bool {
        errors.removeAll()
        var allValid = true

        for section in sections {
            guard let rules = section.validation, let binding = section.binding else { continue }
            for rule in rules {
                if !evaluate(expression: rule.condition, scope: self) {
                    errors[binding] = rule.message
                    allValid = false
                    break // first failure per field
                }
            }
        }

        return allValid
    }

    // MARK: - Serialization

    /// Build a JSONObject from all form values (for API submission).
    public func toJSON() -> JSONObject {
        lock.lock()
        let snapshot = values
        lock.unlock()

        var result: JSONObject = [:]
        for (key, value) in snapshot {
            switch value {
            case .text(let s):       result[key] = .string(s)
            case .number(let n):     result[key] = .double(n)
            case .bool(let b):       result[key] = .bool(b)
            case .selection(let s):  result[key] = .array(s.sorted().map { .string($0) })
            case .files(let f):      result[key] = .array(f.map { .string($0) })
            case .json(let j):       result[key] = j
            case .empty:             result[key] = .null
            }
        }
        return result
    }

    // MARK: - Reset

    /// Reset all values, errors, and dirty tracking.
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        values.removeAll()
        errors.removeAll()
        dirtyPaths.removeAll()
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
