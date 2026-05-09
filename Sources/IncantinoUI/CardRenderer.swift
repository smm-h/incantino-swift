// CardRenderer.swift
// Renders a CardSpec inline (no scroll). Used for chat-embedded cards
// and other non-scrollable section lists.

import SwiftUI
import os

private let logger = Logger(subsystem: "Incantino", category: "CardRenderer")

// MARK: - CardRenderer

/// Renders a CardSpec as a VStack of resolved components (no scroll).
public struct CardRenderer: View {
    let card: CardSpec
    let context: SDUIContext

    @Environment(\.componentRegistry) private var registry

    public init(card: CardSpec, context: SDUIContext) {
        self.card = card
        self.context = context
    }

    public var body: some View {
        VStack(spacing: 0) {
            let visible = card.sections.visible(scope: context.scope)
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, section in
                if let view = registry.resolve(section, context: context) {
                    view
                        .sectionAnimation(
                            section.animation,
                            siblingIndex: index,
                            theme: context.theme
                        )
                } else {
                    let _ = logger.warning("Unknown component type: \(section.component)")
                    EmptyView()
                }
            }
        }
    }
}
