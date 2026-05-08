// ComponentRegistry.swift
// Component resolution and rendering context for the SDUI engine.

import SwiftUI

// MARK: - SDUIContext

/// Context passed to every component during rendering.
/// Provides scope (data resolution), action dispatch, and theme access.
public struct SDUIContext {
    public let scope: any ScopeReading
    public let dispatch: any ActionDispatching
    public let theme: any ThemeReading
    /// Named action definitions from the current screen's `actions` map.
    /// Used by ActionDispatcher for named action resolution (step 2 of the pipeline).
    public let screenActions: [String: NamedActionDefinition]

    public init(
        scope: any ScopeReading,
        dispatch: any ActionDispatching,
        theme: any ThemeReading,
        screenActions: [String: NamedActionDefinition] = [:]
    ) {
        self.scope = scope
        self.dispatch = dispatch
        self.theme = theme
        self.screenActions = screenActions
    }

    /// Write a value to scope if it conforms to ScopeWriting (FormScope, DictionaryScope, etc.).
    public func writeToScope(_ key: String, value: ScopeValue) {
        (scope as? any ScopeWriting)?.set(key, value: value)
    }
}

// MARK: - IncantinoComponent

/// Protocol that all SDUI components conform to.
/// Each component declares a type name and is initialized from a SectionSpec + context.
@MainActor
public protocol IncantinoComponent: View {
    static var typeName: String { get }
    init(spec: SectionSpec, context: SDUIContext)
}

// MARK: - ComponentRegistry

/// Registry mapping component type name strings to view factories.
/// Resolution is O(1) dictionary lookup.
@MainActor
public final class ComponentRegistry {
    public static let shared = ComponentRegistry()

    private var factories: [String: @MainActor (SectionSpec, SDUIContext) -> AnyView] = [:]

    /// Register a component type. Overwrites any previous registration for the same type name.
    public func register<C: IncantinoComponent>(_ type: C.Type) {
        factories[C.typeName] = { spec, ctx in AnyView(C(spec: spec, context: ctx)) }
    }

    /// Resolve a section spec to a rendered view.
    /// Returns nil for unknown component types (caller should render nothing and log).
    public func resolve(_ spec: SectionSpec, context: SDUIContext) -> AnyView? {
        factories[spec.component]?(spec, context)
    }

    /// The set of currently registered component type names.
    public var registeredTypes: Set<String> { Set(factories.keys) }
}

// MARK: - Environment key

/// Environment key for injecting a ComponentRegistry into the SwiftUI view hierarchy.
struct ComponentRegistryKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue = ComponentRegistry.shared
}

extension EnvironmentValues {
    public var componentRegistry: ComponentRegistry {
        get { self[ComponentRegistryKey.self] }
        set { self[ComponentRegistryKey.self] = newValue }
    }
}
