// BadgeComponent.swift
// Small colored pill label.

import SwiftUI

public struct BadgeComponent: IncantinoComponent {
    public static let typeName = "badge"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let label = TextInterpolator.resolve(p.string(forKey: "label") ?? "", scope: context.scope)
        let bgColor = resolveColor(p.string(forKey: "color") ?? "accent", theme: theme)
        let textColor = resolveColor(p.string(forKey: "textColor") ?? "background", theme: theme)

        Text(label)
            .font(theme.font(style: .caption))
            .foregroundStyle(textColor)
            .padding(.horizontal, theme.spacingSM)
            .padding(.vertical, theme.spacingXS)
            .background(bgColor)
            .clipShape(Capsule())
            .accessibilityLabel(label)
    }
}
