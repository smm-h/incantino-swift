// ScreenRenderer.swift
// Renders a ScreenSpec as a scrollable list of resolved components.
// Filters sections by visibility, resolves each through ComponentRegistry,
// and handles unknown component types gracefully (renders nothing, logs).

import SwiftUI
import os

private let logger = Logger(subsystem: "Incantino", category: "ScreenRenderer")

// MARK: - ScreenRenderer

/// Renders a full screen from a ScreenSpec.
/// Sections are visibility-filtered, then resolved through the component registry.
public struct ScreenRenderer: View {
    let screen: ScreenSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(screen: ScreenSpec, context: SDUIContext) {
        self.screen = screen
        self.context = context
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                let visible = screen.sections.visible(scope: context.scope)
                ForEach(Array(visible.enumerated()), id: \.element.id) { _, section in
                    resolveSection(section)
                }
            }
        }
        .onAppear {
            // Sync screen-level named actions to the dispatcher for resolution.
            if let dispatcher = context.dispatch as? ActionDispatcher {
                dispatcher.screenActions = screen.actions ?? [:]
            }
        }
    }

    /// Resolve a single section to a view.
    /// Unknown types render as EmptyView with a warning log.
    @ViewBuilder
    private func resolveSection(_ section: SectionSpec) -> some View {
        if let view = registry.resolve(section, context: context) {
            view
        } else {
            // Unknown component type: render nothing, log warning.
            let _ = logger.warning("Unknown component type: \(section.component)")
            EmptyView()
        }
    }
}
