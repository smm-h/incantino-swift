// TabsComponent.swift
// Segmented control with tab panels.
// Children map 1:1 to tab labels; each child renders in its corresponding panel.

import SwiftUI

public struct TabsComponent: IncantinoComponent {
    public static let typeName = "tabs"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @Environment(\.componentRegistry) private var registry
    @State private var selectedIndex: Int

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
        let defaultIndex = (spec.properties ?? [:]).int(forKey: "defaultIndex") ?? 0
        self._selectedIndex = State(initialValue: defaultIndex)
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let labels = extractLabels(from: p)
        let children = (spec.children ?? []).visible(scope: context.scope)

        VStack(spacing: 0) {
            // Tab bar (segmented-style).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        Button {
                            withAnimation(.easeInOut(duration: theme.animationFast)) {
                                selectedIndex = index
                            }
                        } label: {
                            Text(label)
                                .font(theme.font(style: .subheadline))
                                .padding(.horizontal, theme.spacingMD)
                                .padding(.vertical, theme.spacingSM)
                                .foregroundStyle(
                                    index == selectedIndex
                                        ? theme.accent
                                        : theme.textSecondary
                                )
                                .overlay(alignment: .bottom) {
                                    if index == selectedIndex {
                                        Rectangle()
                                            .fill(theme.accent)
                                            .frame(height: 2)
                                    }
                                }
                        }
                        .accessibilityAddTraits(index == selectedIndex ? .isSelected : [])
                        .accessibilityLabel(label)
                        .accessibilityHint("Tab \(index + 1) of \(labels.count)")
                    }
                }
            }

            // Tab panel content.
            if selectedIndex < children.count {
                let child = children[selectedIndex]
                if let view = registry.resolve(child, context: context) {
                    view
                }
            }
        }
    }

    private func extractLabels(from p: JSONObject) -> [String] {
        guard let arr = p.array(forKey: "labels") else { return [] }
        return arr.compactMap { $0.stringValue }
    }
}
