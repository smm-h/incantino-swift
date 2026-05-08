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

    public init(
        action: String,
        params: JSONObject? = nil,
        guard: String? = nil,
        confirm: ConfirmSpec? = nil,
        haptic: String? = nil,
        onSuccess: Box<ActionSpec>? = nil,
        onError: Box<ActionSpec>? = nil
    ) {
        self.action = action
        self.params = params
        self.guard = `guard`
        self.confirm = confirm
        self.haptic = haptic
        self.onSuccess = onSuccess
        self.onError = onError
    }

    public struct ConfirmSpec: Codable, Sendable {
        public let title: String
        public let message: String
        public let destructive: Bool?
    }
}

// MARK: - ActionSpec navigate helpers

extension ActionSpec {
    /// The navigation target screen ID, extracted from `params["target"]`.
    /// Returns nil if this is not a navigate action or target is missing.
    public var navigateTarget: String? {
        params?.string(forKey: "target")
    }

    /// Route parameters for a navigate action, extracted from the nested `params["params"]` object.
    /// Returns key-value pairs with the `route.` prefix stripped -- callers inject these into
    /// the target screen's scope as `route.<key>`.
    /// Returns an empty dictionary if no route params are present.
    public var routeParams: JSONObject {
        guard let nested = params?.object(forKey: "params") else { return [:] }
        return nested
    }

    /// Route parameters converted to ScopeValues for direct injection into a DictionaryScope.
    /// Each entry maps `"route.<key>"` to the corresponding ScopeValue.
    /// Strings become `.text`, numbers become `.number`, booleans become `.bool`,
    /// complex values become `.json`.
    public var routeScopeValues: [String: ScopeValue] {
        var result: [String: ScopeValue] = [:]
        for (key, jsonValue) in routeParams {
            let scopeValue: ScopeValue
            switch jsonValue {
            case .string(let s): scopeValue = .text(s)
            case .int(let i): scopeValue = .number(Double(i))
            case .double(let d): scopeValue = .number(d)
            case .bool(let b): scopeValue = .bool(b)
            case .null: scopeValue = .empty
            case .array, .object: scopeValue = .json(jsonValue)
            }
            result["route.\(key)"] = scopeValue
        }
        return result
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
    /// Named action definitions. Inline ActionSpecs referencing a key here
    /// resolve to a `submit` action with the definition's endpoint/method.
    public let actions: [String: NamedActionDefinition]?
}

// MARK: - NamedActionDefinition

/// A reusable action definition in a screen's `actions` map.
/// Resolved to a `submit` action with `endpoint` and `method` as params.
public struct NamedActionDefinition: Codable, Sendable {
    public let endpoint: String
    public let method: String?
    public let confirm: ActionSpec.ConfirmSpec?
    public let onSuccess: Box<ActionSpec>?
    public let onError: Box<ActionSpec>?
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

// MARK: - Implicit binding

/// Component types that participate in implicit form binding.
/// When a section uses one of these components and omits the `binding` field,
/// the engine generates `form.<section.id>` as the effective binding path.
private let bindableComponents: Set<String> = [
    "input", "select", "toggle", "checkbox", "slider"
]

extension SectionSpec {
    /// Resolved binding path, applying implicit binding rules:
    /// 1. If `binding` is present and non-empty, use it verbatim.
    /// 2. If `binding` is nil and the component is bindable, generate `form.<id>`.
    /// 3. If `binding` is an empty string, binding is disabled (returns nil).
    public var effectiveBinding: String? {
        if let binding {
            // Explicit binding: use verbatim if non-empty, nil if empty (opt-out).
            return binding.isEmpty ? nil : binding
        }
        // No explicit binding: auto-bind if the component type is bindable.
        if bindableComponents.contains(component) {
            return "form.\(id)"
        }
        return nil
    }
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
