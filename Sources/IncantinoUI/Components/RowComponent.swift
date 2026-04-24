// RowComponent.swift
// Three-slot horizontal row: leading (natural width), content (fills), trailing (natural width).

import SwiftUI

public struct RowComponent: IncantinoComponent {
    public static let typeName = "row"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let spacing = p.double(forKey: "spacing") ?? 12
        let alignment = verticalAlignment(from: p.string(forKey: "alignment"))
        let padding = p.double(forKey: "padding")

        HStack(alignment: alignment, spacing: spacing) {
            // Leading slot (natural width).
            if let leading = spec.slots?["leading"] {
                if let view = registry.resolve(leading, context: context) {
                    view.fixedSize(horizontal: true, vertical: false)
                }
            }

            // Content slot (fills remaining space).
            if let content = spec.slots?["content"] {
                if let view = registry.resolve(content, context: context) {
                    view.frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Trailing slot (natural width).
            if let trailing = spec.slots?["trailing"] {
                if let view = registry.resolve(trailing, context: context) {
                    view.fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .padding(padding.map { CGFloat($0) } ?? 0)
        // Row is accessible as a group, combining slot announcements.
        .accessibilityElement(children: .combine)
    }

    private func verticalAlignment(from value: String?) -> VerticalAlignment {
        switch value {
        case "top": .top
        case "bottom": .bottom
        default: .center
        }
    }
}
