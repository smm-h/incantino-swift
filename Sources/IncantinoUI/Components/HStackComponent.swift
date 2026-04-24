// HStackComponent.swift
// Horizontal stack layout container.

import SwiftUI

public struct HStackComponent: IncantinoComponent {
    public static let typeName = "hstack"

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
        let alignment = verticalAlignment(from: p.string(forKey: "alignment"))
        let padding = p.double(forKey: "padding")

        HStack(alignment: alignment, spacing: spacing) {
            let visible = (spec.children ?? []).visible(scope: context.scope)
            ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                if let view = registry.resolve(child, context: context) {
                    view
                }
            }
        }
        .padding(padding.map { CGFloat($0) } ?? 0)
    }

    private func verticalAlignment(from value: String?) -> VerticalAlignment {
        switch value {
        case "top": .top
        case "bottom": .bottom
        default: .center
        }
    }
}
