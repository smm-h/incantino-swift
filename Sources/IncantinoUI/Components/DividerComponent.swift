// DividerComponent.swift
// Thin horizontal line separator with optional color and inset.
// Hidden from assistive technology.

import SwiftUI

public struct DividerComponent: IncantinoComponent {
    public static let typeName = "divider"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let color = resolveColor(p.string(forKey: "color") ?? "separator", theme: theme)
        let height = p.double(forKey: "height") ?? 1
        let inset = p.double(forKey: "inset")

        Rectangle()
            .fill(color)
            .frame(height: height)
            .padding(.horizontal, inset.map { CGFloat($0) } ?? 0)
            .accessibilityHidden(true)
    }
}
