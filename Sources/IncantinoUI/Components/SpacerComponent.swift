// SpacerComponent.swift
// Empty space. Fixed dimensions or flexible fill.
// Hidden from assistive technology.

import SwiftUI

public struct SpacerComponent: IncantinoComponent {
    public static let typeName = "spacer"

    let spec: SectionSpec
    let context: SDUIContext

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let height = p.double(forKey: "height")
        let width = p.double(forKey: "width")

        if height != nil || width != nil {
            // Fixed-size spacer.
            Color.clear
                .frame(
                    width: width.map { CGFloat($0) },
                    height: height.map { CGFloat($0) }
                )
                .accessibilityHidden(true)
        } else {
            // Flexible spacer.
            Spacer()
                .accessibilityHidden(true)
        }
    }
}
