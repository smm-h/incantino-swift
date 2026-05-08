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
    /// Each slot maps to an array of SectionSpecs. The spec allows either a single
    /// SectionSpec or an array per slot; the decoder normalizes singles to one-element arrays.
    public let slots: [String: [SectionSpec]]?
    public let children: [SectionSpec]?
    public let visibility: String?
    public let binding: String?
    public let action: ActionSpec?
    public let validation: [ValidationRule]?
    public let animation: AnimationSpec?

    private enum CodingKeys: String, CodingKey {
        case id, component, properties, slots, children,
             visibility, binding, action, validation, animation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        component = try container.decode(String.self, forKey: .component)
        properties = try container.decodeIfPresent(JSONObject.self, forKey: .properties)
        children = try container.decodeIfPresent([SectionSpec].self, forKey: .children)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        binding = try container.decodeIfPresent(String.self, forKey: .binding)
        action = try container.decodeIfPresent(ActionSpec.self, forKey: .action)
        validation = try container.decodeIfPresent([ValidationRule].self, forKey: .validation)
        animation = try container.decodeIfPresent(AnimationSpec.self, forKey: .animation)

        // Slots: each value is either a single SectionSpec or an array of SectionSpec.
        // Normalize to [SectionSpec] so consumers always see arrays.
        if container.contains(.slots) {
            let rawSlots = try container.decode([String: OneOrMany].self, forKey: .slots)
            var normalized: [String: [SectionSpec]] = [:]
            for (key, value) in rawSlots {
                switch value {
                case .one(let spec): normalized[key] = [spec]
                case .many(let specs): normalized[key] = specs
                }
            }
            slots = normalized.isEmpty ? nil : normalized
        } else {
            slots = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(component, forKey: .component)
        try container.encodeIfPresent(properties, forKey: .properties)
        try container.encodeIfPresent(children, forKey: .children)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(binding, forKey: .binding)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(validation, forKey: .validation)
        try container.encodeIfPresent(animation, forKey: .animation)
        if let slots = slots {
            var slotsDict: [String: OneOrMany] = [:]
            for (key, sections) in slots {
                slotsDict[key] = sections.count == 1 ? .one(sections[0]) : .many(sections)
            }
            try container.encode(slotsDict, forKey: .slots)
        }
    }
}

/// Helper for decoding a value that may be a single T or an array of T.
private enum OneOrMany: Codable, Sendable {
    case one(SectionSpec)
    case many([SectionSpec])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([SectionSpec].self) {
            self = .many(array)
        } else {
            let single = try container.decode(SectionSpec.self)
            self = .one(single)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .one(let spec): try container.encode(spec)
        case .many(let specs): try container.encode(specs)
        }
    }
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
    public let endpoint: String
    public let params: JSONObject?
    public let options: JSONObject?
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
