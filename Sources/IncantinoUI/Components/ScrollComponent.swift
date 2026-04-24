// ScrollComponent.swift
// Scrollable container with direction and snap behavior.

import SwiftUI

public struct ScrollComponent: IncantinoComponent {
    public static let typeName = "scroll"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let direction = p.string(forKey: "direction") ?? "horizontal"
        let spacing = p.double(forKey: "spacing") ?? 0
        let snap = p.string(forKey: "snap") ?? "none"
        let showsIndicator = p.bool(forKey: "showsIndicator") ?? false
        let isHorizontal = direction == "horizontal"
        let axis: Axis.Set = isHorizontal ? .horizontal : .vertical

        ScrollView(axis, showsIndicators: showsIndicator) {
            let visible = (spec.children ?? []).visible(scope: context.scope)

            if isHorizontal {
                LazyHStack(spacing: spacing) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                        if let view = registry.resolve(child, context: context) {
                            view
                        }
                    }
                }
            } else {
                LazyVStack(spacing: spacing) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                        if let view = registry.resolve(child, context: context) {
                            view
                        }
                    }
                }
            }
        }
        .applySnapBehavior(snap)
    }
}

// MARK: - Snap behavior modifier

private extension View {
    /// Apply scroll snap behavior based on the snap property string.
    @ViewBuilder
    func applySnapBehavior(_ snap: String) -> some View {
        switch snap {
        case "start", "center":
            self.scrollTargetBehavior(.viewAligned)
        case "paging":
            self.scrollTargetBehavior(.paging)
        default:
            self
        }
    }
}
