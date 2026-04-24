// DialogComponent.swift
// Centered modal dialog with overlay, title, message, and footer actions.

import SwiftUI

public struct DialogComponent: IncantinoComponent {
    public static let typeName = "dialog"

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
        let message = p.string(forKey: "message").map {
            TextInterpolator.resolve($0, scope: context.scope)
        }

        // Render as a ZStack overlay for full control over dialog appearance.
        if isPresented {
            ZStack {
                // Scrim overlay.
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismiss()
                    }

                // Dialog card.
                VStack(spacing: theme.spacingMD) {
                    if let title {
                        Text(title)
                            .font(theme.font(style: .headline))
                            .foregroundStyle(theme.textPrimary)
                    }

                    // Content slot overrides message if provided.
                    if let content = spec.slots?["content"],
                       let view = registry.resolve(content, context: context) {
                        view
                    } else if let message {
                        Text(message)
                            .font(theme.font(style: .body))
                            .foregroundStyle(theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Footer slot (action buttons).
                    if let footer = spec.slots?["footer"],
                       let view = registry.resolve(footer, context: context) {
                        view
                    }
                }
                .padding(theme.spacingLG)
                .frame(maxWidth: 320)
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
                .shadow(radius: 8)
                .accessibilityLabel(title ?? "Dialog")
                .accessibilityAddTraits(.isModal)
            }
        }
    }

    private func dismiss() {
        isPresented = false
        // Fire onDismiss action if configured.
        if let action = spec.action {
            let dispatcher = context.dispatch
            let scope = context.scope
            Task { @MainActor in
                if let dispatcher = dispatcher as? ActionDispatcher {
                    await dispatcher.dispatchSpec(action, scope: scope)
                } else {
                    await dispatcher.dispatch(
                        action: action.action,
                        params: action.params ?? [:],
                        scope: scope
                    )
                }
            }
        }
    }
}
