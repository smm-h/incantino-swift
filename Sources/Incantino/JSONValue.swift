// JSONValue.swift
// Type-safe JSON value enum with full Codable conformance.

import Foundation

/// Type alias for a JSON object (string-keyed dictionary of JSONValue).
public typealias JSONObject = [String: JSONValue]

/// A type-safe representation of a JSON value.
public enum JSONValue: Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object(JSONObject)
    case null
}

// MARK: - Codable

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }
        // Bool must be checked before Int because Bool conforms to FixedWidthInteger
        // in some contexts, but in JSON decoding we rely on JSONDecoder's type
        // discrimination. We try bool first to avoid 0/1 being decoded as int.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode(JSONObject.self) {
            self = .object(value)
            return
        }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode JSONValue"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - ExpressibleBy literals

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

// MARK: - Typed accessors

public extension JSONValue {
    /// Returns the string value if this is a `.string`, nil otherwise.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Returns the int value if this is an `.int`, nil otherwise.
    var intValue: Int? {
        if case .int(let i) = self { return i }
        return nil
    }

    /// Returns the double value if this is a `.double`, nil otherwise.
    /// Also returns the double representation of `.int`.
    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        default: return nil
        }
    }

    /// Returns the bool value if this is a `.bool`, nil otherwise.
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    /// Returns the array if this is an `.array`, nil otherwise.
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// Returns the object if this is an `.object`, nil otherwise.
    var objectValue: JSONObject? {
        if case .object(let o) = self { return o }
        return nil
    }

    /// Returns true if this is `.null`.
    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

// MARK: - Typed accessors on Dictionary<String, JSONValue>

public extension Dictionary where Key == String, Value == JSONValue {
    /// Look up a key and return its string value, or nil.
    func string(forKey key: String) -> String? {
        self[key]?.stringValue
    }

    /// Look up a key and return its int value, or nil.
    func int(forKey key: String) -> Int? {
        self[key]?.intValue
    }

    /// Look up a key and return its double value, or nil.
    func double(forKey key: String) -> Double? {
        self[key]?.doubleValue
    }

    /// Look up a key and return its bool value, or nil.
    func bool(forKey key: String) -> Bool? {
        self[key]?.boolValue
    }

    /// Look up a key and return its array value, or nil.
    func array(forKey key: String) -> [JSONValue]? {
        self[key]?.arrayValue
    }

    /// Look up a key and return its object value, or nil.
    func object(forKey key: String) -> JSONObject? {
        self[key]?.objectValue
    }
}
