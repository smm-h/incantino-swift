// SheetComponent.swift
// Bottom sheet modal with drag handle, title, and child content.

import SwiftUI

public struct SheetComponent: IncantinoComponent {
    public static let typeName = "sheet"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @Environment(\.componentRegistry) private var registry
    @State private var isPresented: Bool = true

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let title = p.string(forKey: "title").map {
            TextInterpolator.resolve($0, scope: context.scope)
        }
        let detent = p.string(forKey: "detent") ?? "large"
        let scrollable = p.bool(forKey: "scrollable") ?? true
        let backgroundColorName = p.string(forKey: "background")

        // The sheet is presented as a .sheet modifier on an empty anchor view.
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $isPresented) {
                // On dismiss callback.
                if let action = spec.action {
                    let dispatcher = context.dispatch
                    let scope = context.scope
                    Task { @MainActor in
                        await dispatcher.dispatch(action, scope: scope, screenActions: context.screenActions)
                    }
                }
            } content: {
                sheetContent(title: title, scrollable: scrollable, backgroundColorName: backgroundColorName)
                    .presentationDetents(sheetDetents(detent))
                    .presentationDragIndicator(.visible)
                    .accessibilityLabel(title ?? "Sheet")
            }
    }

    @ViewBuilder
    private func sheetContent(title: String?, scrollable: Bool, backgroundColorName: String?) -> some View {
        let content = VStack(spacing: 0) {
            // Drag handle.
            Capsule()
                .fill(theme.separator)
                .frame(width: 36, height: 5)
                .padding(.top, theme.spacingSM)

            if let title {
                Text(title)
                    .font(theme.font(style: .headline))
                    .padding(.top, theme.spacingSM)
            }

            // Children content: scrollable or fixed layout.
            if scrollable {
                ScrollView {
                    childrenStack
                }
            } else {
                childrenStack
            }
        }

        if let backgroundColorName {
            content.background(resolveColor(backgroundColorName, theme: theme))
        } else {
            content
        }
    }

    private var childrenStack: some View {
        VStack(spacing: 0) {
            let visible = (spec.children ?? []).visible(scope: context.scope)
            ForEach(Array(visible.enumerated()), id: \.element.id) { _, child in
                if let view = registry.resolve(child, context: context) {
                    view
                }
            }
        }
    }

    private func sheetDetents(_ detent: String) -> Set<PresentationDetent> {
        switch detent {
        case "medium": [.medium]
        case "full": [.large]
        default: [.large]
        }
    }
}
