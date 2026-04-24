// TimelineComponent.swift
// Step timeline with vertical connecting line and status dots.
// Each child is a step; currentIndex determines completed/current/pending state.

import SwiftUI

public struct TimelineComponent: IncantinoComponent {
    public static let typeName = "timeline"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @Environment(\.componentRegistry) private var registry

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let currentIndex = p.int(forKey: "currentIndex") ?? 0
        let lineColor = resolveColor(p.string(forKey: "lineColor") ?? "accent", theme: theme)
        let children = (spec.children ?? []).visible(scope: context.scope)
        let totalSteps = children.count

        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                HStack(alignment: .top, spacing: theme.spacingSM) {
                    // Status dot and connecting line.
                    VStack(spacing: 0) {
                        Circle()
                            .fill(dotColor(index: index, current: currentIndex, lineColor: lineColor))
                            .frame(width: 12, height: 12)
                            .overlay {
                                if index == currentIndex {
                                    Circle()
                                        .strokeBorder(lineColor, lineWidth: 2)
                                        .frame(width: 18, height: 18)
                                }
                            }

                        // Connecting line (not after last step).
                        if index < totalSteps - 1 {
                            Rectangle()
                                .fill(index < currentIndex ? lineColor : theme.separator)
                                .frame(width: 2)
                                .frame(minHeight: 30)
                        }
                    }

                    // Step content.
                    if let view = registry.resolve(child, context: context) {
                        view
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Step \(index + 1) of \(totalSteps)")
                .accessibilityValue(stepStatus(index: index, current: currentIndex))
            }
        }
    }

    private func dotColor(index: Int, current: Int, lineColor: Color) -> Color {
        if index < current { return lineColor }           // Completed.
        if index == current { return lineColor }           // Current.
        return theme.separator                              // Pending.
    }

    private func stepStatus(index: Int, current: Int) -> String {
        if index < current { return "completed" }
        if index == current { return "current" }
        return "pending"
    }
}
