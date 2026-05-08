// ButtonComponent.swift
// Action button with 4 style variants (primary, secondary, ghost, destructive).

import SwiftUI

public struct ButtonComponent: IncantinoComponent {
    public static let typeName = "button"

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
        let style = p.string(forKey: "style") ?? "primary"
        let iconName = p.string(forKey: "icon")

        let isEnabled = p.string(forKey: "enabled").map { evaluate(expression: $0, scope: context.scope) } ?? true

        Button {
            guard let action = spec.action else { return }
            let dispatcher = context.dispatch
            let scope = context.scope
            Task { @MainActor in
                await dispatcher.dispatch(action, scope: scope, screenActions: context.screenActions)
            }
        } label: {
            HStack(spacing: 6) {
                if let iconName {
                    Image(systemName: iconName)
                }
                Text(label)
            }
            .frame(maxWidth: style == "ghost" ? nil : .infinity)
            .padding(.horizontal, theme.spacingMD)
            .padding(.vertical, theme.spacingSM)
            .background(backgroundColor(style: style))
            .foregroundStyle(foregroundColor(style: style))
            .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius))
            .overlay(borderOverlay(style: style))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(label)
    }

    // MARK: - Style helpers

    private func backgroundColor(style: String) -> Color {
        switch style {
        case "primary": theme.accent
        case "secondary": theme.surface
        case "destructive": theme.error
        case "ghost": .clear
        default: theme.accent
        }
    }

    private func foregroundColor(style: String) -> Color {
        switch style {
        case "primary": theme.background
        case "secondary": theme.accent
        case "destructive": theme.background
        case "ghost": theme.accent
        default: theme.background
        }
    }

    @ViewBuilder
    private func borderOverlay(style: String) -> some View {
        if style == "secondary" {
            RoundedRectangle(cornerRadius: theme.buttonCornerRadius)
                .strokeBorder(theme.separator, lineWidth: 1)
        }
    }
}
