// AccordionComponent.swift
// Collapsible section with animated expand/collapse.

import SwiftUI

public struct AccordionComponent: IncantinoComponent {
    public static let typeName = "accordion"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @Environment(\.componentRegistry) private var registry
    @State private var isExpanded: Bool

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
        let expanded = (spec.properties ?? [:]).bool(forKey: "expanded") ?? false
        self._isExpanded = State(initialValue: expanded)
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let header = TextInterpolator.resolve(p.string(forKey: "header") ?? "", scope: context.scope)

        VStack(alignment: .leading, spacing: 0) {
            // Header button.
            Button {
                withAnimation(.easeInOut(duration: theme.animationFast)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(header)
                        .font(theme.font(style: .headline))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(theme.textSecondary)
                }
                .padding(.vertical, theme.spacingSM)
            }
            .accessibilityLabel(header)
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityHint("Tap to \(isExpanded ? "collapse" : "expand")")

            // Children (hidden when collapsed).
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    let visible = (spec.children ?? []).visible(scope: context.scope)
                    ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                        if let view = registry.resolve(child, context: context) {
                            view
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
