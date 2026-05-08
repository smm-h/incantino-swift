// SliderComponent.swift
// Range slider with min/max/step, binding to scope.

import SwiftUI

public struct SliderComponent: IncantinoComponent {
    public static let typeName = "slider"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @State private var value: Double = 0

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let minVal = p.double(forKey: "min") ?? 0
        let maxVal = p.double(forKey: "max") ?? 1
        let step = p.double(forKey: "step")
        let label = TextInterpolator.resolve(p.string(forKey: "label") ?? "", scope: context.scope)

        VStack(alignment: .leading, spacing: theme.spacingXS) {
            Text(label)
                .font(theme.font(style: .body))
                .foregroundStyle(theme.textPrimary)

            if let step {
                Slider(value: $value, in: minVal...maxVal, step: step)
                    .tint(theme.accent)
            } else {
                Slider(value: $value, in: minVal...maxVal)
                    .tint(theme.accent)
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue("\(formatNumber(value))")
        .onAppear { loadInitialValue() }
        .onChange(of: value) { _, newValue in
            writeToScope(newValue)
        }
    }

    private func loadInitialValue() {
        guard let binding = spec.effectiveBinding else { return }
        if let val = context.scope.resolve(binding).doubleValue {
            value = val
        }
    }

    private func writeToScope(_ val: Double) {
        guard let binding = spec.effectiveBinding else { return }
        context.writeToScope(binding, value: .number(val))
    }
}
