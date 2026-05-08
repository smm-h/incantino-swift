// CardComponent.swift
// Elevated surface with media, content, and footer slots.
// Supports 3 media positions: top, leading, background.

import SwiftUI

public struct CardComponent: IncantinoComponent {
    public static let typeName = "card"

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
        let position = p.string(forKey: "mediaPosition") ?? "top"
        let cornerRadius = p.double(forKey: "cornerRadius") ?? Double(theme.cardCornerRadius)
        let elevation = p.string(forKey: "elevation") ?? "low"

        let card = Group {
            switch position {
            case "leading": leadingLayout
            case "background": backgroundLayout(dim: p.double(forKey: "mediaDim") ?? 0.3)
            default: topLayout
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .shadow(radius: shadowRadius(for: elevation))
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(theme.surface)
        )

        // If card has an action, wrap in a button.
        if let action = spec.action {
            Button {
                let dispatcher = context.dispatch
                let scope = context.scope
                Task { @MainActor in
                    await dispatcher.dispatch(action, scope: scope, screenActions: context.screenActions)
                }
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    // MARK: - Media position layouts

    private var topLayout: some View {
        VStack(spacing: 0) {
            slotView("media")
            contentAndFooter
        }
    }

    private var leadingLayout: some View {
        HStack(spacing: 0) {
            slotView("media")
                .frame(width: 100)
                .clipped()
            contentAndFooter
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func backgroundLayout(dim: Double) -> some View {
        ZStack {
            slotView("media")
            Color.black.opacity(dim)
            contentAndFooter
        }
    }

    private var contentAndFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spec.slots?["header"]?.isEmpty == false {
                slotView("header")
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.top, theme.spacingSM)
            }
            slotView("content")
                .padding(theme.spacingMD)
            if spec.slots?["footer"]?.isEmpty == false {
                slotView("footer")
                    .padding(.horizontal, theme.spacingMD)
                    .padding(.bottom, theme.spacingSM)
            }
        }
    }

    // MARK: - Slot rendering

    @ViewBuilder
    private func slotView(_ name: String) -> some View {
        if let slot = spec.slots?[name]?.first,
           let view = registry.resolve(slot, context: context) {
            view
        }
    }

    private func shadowRadius(for elevation: String) -> CGFloat {
        switch elevation {
        case "none": 0
        case "low": 2
        case "medium": 4
        case "high": 8
        default: 2
        }
    }
}
