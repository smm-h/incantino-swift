// Scope.swift
// Scope value model and scope resolution with progressive prefix matching.

import Foundation

// MARK: - ScopeValue

/// Tagged union representing a single value stored in a scope.
public enum ScopeValue: Sendable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case selection(Set<String>)
    case files([String])
    case json(JSONValue)
    case empty
}

// MARK: - Truthiness

extension ScopeValue {
    /// Whether this value is truthy (non-empty, non-zero, non-false).
    public var isTruthy: Bool {
        switch self {
        case .text(let s): return !s.isEmpty
        case .number(let n): return n != 0
        case .bool(let b): return b
        case .selection(let s): return !s.isEmpty
        case .files(let f): return !f.isEmpty
        case .json(let j): return j.jsonTruthy
        case .empty: return false
        }
    }
}

// MARK: - Cross-type coercion accessors

extension ScopeValue {
    /// Returns a Double if this value can be interpreted as a number.
    public var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .json(let j):
            switch j {
            case .double(let d): return d
            case .int(let i): return Double(i)
            default: return nil
            }
        case .text(let s): return Double(s)
        default: return nil
        }
    }

    /// Returns a Bool only for explicit boolean types.
    public var boolValue: Bool? {
        switch self {
        case .bool(let b): return b
        case .json(.bool(let b)): return b
        default: return nil
        }
    }

    /// Returns a string representation if available.
    public var stringValue: String? {
        switch self {
        case .text(let s): return s
        case .number(let n): return formatNumber(n)
        case .bool(let b): return b ? "true" : "false"
        case .json(let j):
            switch j {
            case .string(let s): return s
            case .int(let i): return String(i)
            case .double(let d): return formatNumber(d)
            case .bool(let b): return b ? "true" : "false"
            default: return nil
            }
        default: return nil
        }
    }

    /// Element count for collection-like types.
    public var elementCount: Int {
        switch self {
        case .text(let s): return s.count
        case .selection(let s): return s.count
        case .files(let f): return f.count
        case .json(let j):
            switch j {
            case .array(let a): return a.count
            case .object(let o): return o.count
            case .string(let s): return s.count
            default: return 0
            }
        default: return 0
        }
    }
}

// MARK: - JSON truthiness

extension JSONValue {
    /// Whether this JSON value is truthy.
    var jsonTruthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .string(let s): return !s.isEmpty
        case .int(let i): return i != 0
        case .double(let d): return d != 0
        case .array(let a): return !a.isEmpty
        case .object(let o): return !o.isEmpty
        }
    }
}

// MARK: - Number formatting

/// Format a number for display: drop .0 for whole numbers.
public func formatNumber(_ n: Double) -> String {
    if n.truncatingRemainder(dividingBy: 1) == 0 && n.isFinite {
        return String(Int(n))
    }
    return String(n)
}

// MARK: - ScopeReading protocol

/// Read-only access to a scope chain.
public protocol ScopeReading: Sendable {
    /// Resolve a dot-path to a scope value.
    func resolve(_ path: String) -> ScopeValue
}

// MARK: - ScopeWriting protocol

/// Read-write access to a scope. Extends ScopeReading.
public protocol ScopeWriting: ScopeReading {
    /// Write a value at the given key.
    func set(_ key: String, value: ScopeValue)
}

// MARK: - EmptyScope

/// Terminal scope that always returns .empty. Used as the chain terminator.
public final class EmptyScope: ScopeReading, Sendable {
    public init() {}

    public func resolve(_ path: String) -> ScopeValue {
        .empty
    }
}

// MARK: - Property resolution (shared logic)

/// Resolve a property suffix on a scope value.
/// Used by DictionaryScope and other ScopeReading implementations.
func resolveProperty(_ property: String, on value: ScopeValue) -> ScopeValue {
    // Terminal properties.
    switch property {
    case "isEmpty":
        return .bool(!value.isTruthy)
    case "isNotEmpty":
        return .bool(value.isTruthy)
    case "count", "length":
        return .number(Double(value.elementCount))
    default:
        break
    }

    // JSON path walking.
    if case .json(let j) = value {
        return resolveJsonPath(property, on: j)
    }

    return .empty
}

/// Walk a dot-path into a JSON value tree.
func resolveJsonPath(_ path: String, on jsonVal: JSONValue) -> ScopeValue {
    if case .null = jsonVal {
        return .json(.null)
    }

    // Split at first dot.
    let head: String
    let tail: String?
    if let dotIndex = path.firstIndex(of: ".") {
        head = String(path[path.startIndex..<dotIndex])
        tail = String(path[path.index(after: dotIndex)...])
    } else {
        head = path
        tail = nil
    }

    // Try to find child.
    var child: JSONValue?

    switch jsonVal {
    case .object(let obj):
        child = obj[head]
    case .array(let arr):
        if let idx = Int(head), idx >= 0, idx < arr.count {
            child = arr[idx]
        }
    default:
        break
    }

    if let child = child {
        if let tail = tail {
            return resolveJsonPath(tail, on: child)
        }
        return .json(child)
    }

    // Terminal properties on JSON values.
    switch head {
    case "isEmpty":
        return .json(.bool(!jsonVal.jsonTruthy))
    case "isNotEmpty":
        return .json(.bool(jsonVal.jsonTruthy))
    case "count", "length":
        let c: Int
        switch jsonVal {
        case .string(let s): c = s.count
        case .array(let a): c = a.count
        case .object(let o): c = o.count
        default: c = 0
        }
        return .json(.int(c))
    default:
        return .json(.null)
    }
}

// MARK: - DictionaryScope

/// A general-purpose scope backed by a string-keyed dictionary.
/// Supports parent chain and progressive prefix matching for dot paths.
/// Thread-safe via NSLock.
public final class DictionaryScope: ScopeWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: ScopeValue]
    private let parent: (any ScopeReading)?

    public init(values: [String: ScopeValue] = [:], parent: (any ScopeReading)? = nil) {
        self.values = values
        self.parent = parent
    }

    public func resolve(_ path: String) -> ScopeValue {
        lock.lock()
        defer { lock.unlock() }

        // 1. Exact match.
        if let value = values[path] {
            return value
        }

        // 2. Progressive prefix matching (longest prefix first).
        // Find all dot positions, iterate from rightmost to leftmost.
        let pathChars = Array(path)
        var dotPositions: [Int] = []
        for (i, c) in pathChars.enumerated() {
            if c == "." {
                dotPositions.append(i)
            }
        }

        for pos in dotPositions.reversed() {
            let prefix = String(pathChars[0..<pos])
            let suffix = String(pathChars[(pos + 1)...])
            if let value = values[prefix] {
                return resolveProperty(suffix, on: value)
            }
        }

        // 3. Parent delegation.
        if let parent = parent {
            // Unlock before calling parent to avoid holding our lock while
            // another scope's lock is acquired (prevents deadlocks in chains).
            // We already captured the parent reference above, so re-read is fine.
            lock.unlock()
            let result = parent.resolve(path)
            lock.lock()
            return result
        }

        return .empty
    }

    public func set(_ key: String, value: ScopeValue) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    /// Read all current values (snapshot). Useful for testing/debugging.
    public func allValues() -> [String: ScopeValue] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }
}
