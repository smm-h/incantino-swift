// IconComponent.swift
// Platform-native icon (SF Symbol on iOS) with size and color.

import SwiftUI

public struct IconComponent: IncantinoComponent {
    public static let typeName = "icon"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let name = p.string(forKey: "name") ?? "questionmark"
        let size = p.double(forKey: "size") ?? 20
        let color = resolveColor(p.string(forKey: "color"), theme: theme)
        let label = p.string(forKey: "accessibilityLabel")

        Image(systemName: name)
            .font(.system(size: size))
            .foregroundStyle(color)
            .accessibilityLabel(label ?? name)
    }
}
