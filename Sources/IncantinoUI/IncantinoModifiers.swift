// IncantinoModifiers.swift
// View modifiers for configuring Incantino from the outside.

import SwiftUI

// MARK: - Scope environment key

/// Environment key for injecting a scope into the view hierarchy.
struct SDUIScopeKey: EnvironmentKey {
    static let defaultValue: any ScopeReading = EmptyScope()
}

extension EnvironmentValues {
    public var sduiScope: any ScopeReading {
        get { self[SDUIScopeKey.self] }
        set { self[SDUIScopeKey.self] = newValue }
    }
}

// MARK: - View modifiers

extension View {
    /// Set the Incantino theme for this view hierarchy.
    public func incantinoTheme(_ theme: any ThemeReading) -> some View {
        environment(\.theme, theme)
    }

    /// Set the Incantino scope for this view hierarchy.
    public func incantinoScope(_ scope: any ScopeReading) -> some View {
        environment(\.sduiScope, scope)
    }

    /// Register a custom component with the shared registry for this view hierarchy.
    public func incantinoComponent<C: IncantinoComponent>(_ type: C.Type) -> some View {
        // Registration is a one-time side effect; onAppear fires when the view
        // enters the hierarchy, which is the earliest safe point in SwiftUI.
        onAppear { ComponentRegistry.shared.register(type) }
    }
}
