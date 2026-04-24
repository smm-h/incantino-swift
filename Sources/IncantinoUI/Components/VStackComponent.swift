// VStackComponent.swift
// Vertical stack layout container.

import SwiftUI

public struct VStackComponent: IncantinoComponent {
    public static let typeName = "vstack"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let spacing = p.double(forKey: "spacing") ?? 0
        let alignment = horizontalAlignment(from: p.string(forKey: "alignment"))
        let padding = p.double(forKey: "padding")

        VStack(alignment: alignment, spacing: spacing) {
            let visible = (spec.children ?? []).visible(scope: context.scope)
            ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                if let view = registry.resolve(child, context: context) {
                    view
                }
            }
        }
        .padding(padding.map { CGFloat($0) } ?? 0)
    }

    private func horizontalAlignment(from value: String?) -> HorizontalAlignment {
        switch value {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }
}
