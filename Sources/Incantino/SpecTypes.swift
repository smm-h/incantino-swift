// SpecTypes.swift
// All SDUI spec types as Codable structs.
// These are the data structures that configs decode into.

import Foundation

// MARK: - Box (recursive wrapper)

/// Heap-allocated wrapper for recursive value types.
/// Used by ActionSpec for onSuccess/onError chaining.
public final class Box<T: Codable & Sendable>: Codable, Sendable {
    public let value: T

    public init(_ value: T) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        value = try T(from: decoder)
    }

    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

// MARK: - ActionSpec

/// Unified action model with guard, confirm, haptic, and chaining.
public struct ActionSpec: Codable, Sendable {
    public let action: String
    public let params: JSONObject?
    public let `guard`: String?
    public let confirm: ConfirmSpec?
    public let haptic: String?
    public let onSuccess: Box<ActionSpec>?
    public let onError: Box<ActionSpec>?

    public struct ConfirmSpec: Codable, Sendable {
        public let title: String
        public let message: String
        public let destructive: Bool?
    }
}

// MARK: - SectionSpec

/// A section in a screen -- the recursive building block of UI layout.
/// Sections nest via named slots and ordered children, forming a tree.
public struct SectionSpec: Codable, Sendable {
    public let id: String
    public let component: String
    public let properties: JSONObject?
    public let slots: [String: SectionSpec]?
    public let children: [SectionSpec]?
    public let visibility: String?
    public let binding: String?
    public let action: ActionSpec?
    public let validation: [ValidationRule]?
    public let animation: AnimationSpec?
}

// MARK: - ValidationRule

public struct ValidationRule: Codable, Sendable {
    /// Boolean expression that must be true for the field to be valid.
    public let condition: String
    /// Error message shown when validation fails.
    public let message: String
}

// MARK: - AnimationSpec

public struct AnimationSpec: Codable, Sendable {
    /// Animation token name for entry transition.
    public let entry: String?
    /// Animation token name for press feedback.
    public let press: String?
}

// MARK: - ScreenSpec

/// A screen definition: an ordered list of sections with optional data sources.
public struct ScreenSpec: Codable, Sendable {
    public let id: String
    public let title: String?
    public let background: String?
    public let sections: [SectionSpec]
    public let data: [String: DataSourceSpec]?
}

// MARK: - DataSourceSpec

public struct DataSourceSpec: Codable, Sendable {
    public let source: String
    public let function: String?
    public let table: String?
    public let params: JSONObject?
    public let single: Bool?
}

// MARK: - CardSpec

/// A card shown inline (e.g., in chat). Just a list of sections.
public struct CardSpec: Codable, Sendable {
    public let sections: [SectionSpec]
}

// MARK: - ScopePathDeclaration

/// Scope path declaration for validation -- declares a typed path
/// available in the scope tree.
public struct ScopePathDeclaration: Codable, Sendable {
    public let path: String
    public let type: ScopeValueType
    public let defaultValue: JSONValue?
    public let source: ScopeSource?
}

/// Data type of a scope path value.
public enum ScopeValueType: String, Codable, Sendable {
    case bool, text, number, selection, files
}

/// Origin of a scope value.
public enum ScopeSource: String, Codable, Sendable {
    case config, auth, form, runtime
}

// MARK: - Visibility filtering

extension Array where Element == SectionSpec {
    /// Filter sections to only those whose visibility expression evaluates to true.
    /// Sections without a visibility expression are always included.
    public func visible(scope: any ScopeReading) -> [SectionSpec] {
        filter { section in
            guard let expr = section.visibility else { return true }
            return evaluate(expression: expr, scope: scope)
        }
    }
}
