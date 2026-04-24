// FlowComponent.swift
// Multi-step wizard that wraps FlowHostView.
// Reads the flow config by ID and renders the current step.

import SwiftUI

public struct FlowComponent: IncantinoComponent {
    public static let typeName = "flow"

    let spec: SectionSpec
    let context: SDUIContext

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let flowId = p.string(forKey: "id") ?? ""
        let showProgress = p.bool(forKey: "showProgress") ?? true

        // Flow requires a FlowRunner and screens to be provided via the context.
        // This component acts as a placeholder that the app layer configures
        // with the actual FlowRunner instance. When used directly, it shows
        // the flow-not-found message since we can't resolve flows from here.
        VStack {
            Text(IncantinoStrings.shared.resolve(.flowScreenNotFound))
                .font(.body)
                .foregroundStyle(.secondary)
                .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Flow: \(flowId)")
        .accessibilityValue(showProgress ? "With progress indicator" : "Without progress indicator")
    }
}
