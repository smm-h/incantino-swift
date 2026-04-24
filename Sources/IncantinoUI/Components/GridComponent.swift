// GridComponent.swift
// N-column grid layout using LazyVGrid.

import SwiftUI

public struct GridComponent: IncantinoComponent {
    public static let typeName = "grid"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let columns = p.int(forKey: "columns") ?? 2
        let spacing = p.double(forKey: "spacing") ?? 8
        let rowSpacing = p.double(forKey: "rowSpacing") ?? spacing

        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: max(columns, 1)
        )

        LazyVGrid(columns: gridColumns, spacing: rowSpacing) {
            let visible = (spec.children ?? []).visible(scope: context.scope)
            ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                if let view = registry.resolve(child, context: context) {
                    view
                }
            }
        }
    }
}
