// CheckboxComponent.swift
// Boolean checkbox with label, styled as a checkbox rather than a switch.

import SwiftUI

public struct CheckboxComponent: IncantinoComponent {
    public static let typeName = "checkbox"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @State private var isChecked: Bool = false

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let label = TextInterpolator.resolve(p.string(forKey: "label") ?? "", scope: context.scope)

        Button {
            isChecked.toggle()
            writeToScope(isChecked)
        } label: {
            HStack(spacing: theme.spacingSM) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isChecked ? theme.accent : theme.textSecondary)
                    .font(.system(size: 22))

                Text(label)
                    .font(theme.font(style: .body))
                    .foregroundStyle(theme.textPrimary)
            }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isChecked ? "checked" : "unchecked")
        .onAppear { loadInitialValue() }
    }

    private func loadInitialValue() {
        guard let binding = spec.binding else { return }
        if let val = context.scope.resolve(binding).boolValue {
            isChecked = val
        }
    }

    private func writeToScope(_ value: Bool) {
        guard let binding = spec.binding else { return }
        if let scope = context.scope as? FormScope {
            scope.set(binding, value: .bool(value))
        } else if let scope = context.scope as? DictionaryScope {
            scope.set(binding, value: .bool(value))
        }
    }
}
