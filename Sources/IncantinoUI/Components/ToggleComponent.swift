// ToggleComponent.swift
// On/off toggle switch with label, binding to scope.

import SwiftUI

public struct ToggleComponent: IncantinoComponent {
    public static let typeName = "toggle"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @State private var isOn: Bool = false

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let label = TextInterpolator.resolve(p.string(forKey: "label") ?? "", scope: context.scope)

        Toggle(label, isOn: $isOn)
            .font(theme.font(style: .body))
            .tint(theme.accent)
            .onAppear { loadInitialValue() }
            .onChange(of: isOn) { _, newValue in
                writeToScope(newValue)
            }
    }

    private func loadInitialValue() {
        guard let binding = spec.effectiveBinding else { return }
        if let val = context.scope.resolve(binding).boolValue {
            isOn = val
        }
    }

    private func writeToScope(_ value: Bool) {
        guard let binding = spec.effectiveBinding else { return }
        if let scope = context.scope as? FormScope {
            scope.set(binding, value: .bool(value))
        } else if let scope = context.scope as? DictionaryScope {
            scope.set(binding, value: .bool(value))
        }
    }
}
