// FlowHostView.swift
// SwiftUI host for multi-step flows.
// Wraps a FlowRunner, renders the current step's screen via ScreenRenderer,
// shows progress indicator, and handles flow.next/flow.back actions.

import SwiftUI

// MARK: - FlowHostView

/// Hosts a multi-step flow, rendering the current step and progress indicator.
@MainActor
public struct FlowHostView: View {
    let flowRunner: FlowRunner
    let screens: [String: ScreenSpec]
    let context: SDUIContext
    let showProgress: Bool

    @State private var currentScreenId: String
    @State private var isComplete: Bool = false

    @Environment(\.theme) private var theme

    public init(
        flowRunner: FlowRunner,
        screens: [String: ScreenSpec],
        context: SDUIContext,
        showProgress: Bool = true
    ) {
        self.flowRunner = flowRunner
        self.screens = screens
        self.context = context
        self.showProgress = showProgress
        self._currentScreenId = State(initialValue: flowRunner.currentScreenId)
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showProgress && !isComplete {
                progressIndicator
            }

            if isComplete {
                // Flow completed -- nothing more to render.
                EmptyView()
            } else if let screen = screens[currentScreenId] {
                ScreenRenderer(screen: screen, context: context)
            } else {
                // Missing screen: show engine string.
                Text(IncantinoStrings.shared.resolve(.flowScreenNotFound))
                    .foregroundStyle(theme.error)
                    .padding()
            }
        }
    }

    // MARK: - Progress indicator

    private var progressIndicator: some View {
        let activeIndex = flowRunner.activeStepIndex(scope: context.scope)
        let activeCount = flowRunner.activeStepCount(scope: context.scope)

        return HStack(spacing: theme.spacingXS) {
            ForEach(0..<activeCount, id: \.self) { index in
                Capsule()
                    .fill(index <= activeIndex ? theme.accent : theme.separator)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, theme.spacingMD)
        .padding(.vertical, theme.spacingSM)
        .accessibilityElement()
        .accessibilityLabel(
            IncantinoStrings.shared.resolve(.flowBack)
        )
        .accessibilityValue("Step \(activeIndex + 1) of \(activeCount)")
    }

    // MARK: - Flow navigation

    /// Advance the flow. Validates the current step's form fields first;
    /// if any validation rule fails, the advance is suppressed and errors
    /// are populated on the FormScope (input components display them).
    public func advance() {
        // Validate current step before advancing.
        if let screen = screens[currentScreenId],
           let formScope = context.scope as? FormScope {
            let sections = screen.sections.allSectionsRecursive()
            if !formScope.validate(sections: sections) {
                return
            }
        }

        if let nextId = flowRunner.advance(scope: context.scope) {
            currentScreenId = nextId
        } else {
            isComplete = flowRunner.isComplete
        }
    }

    /// Retreat the flow. Call this from action dispatch when flow.back fires.
    public func retreat() {
        if let prevId = flowRunner.retreat() {
            currentScreenId = prevId
        }
    }
}
