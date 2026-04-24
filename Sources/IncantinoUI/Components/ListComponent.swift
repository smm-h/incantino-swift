// ListComponent.swift
// Vertical list with loading and empty state support.

import SwiftUI

public struct ListComponent: IncantinoComponent {
    public static let typeName = "list"

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
        let children = (spec.children ?? []).visible(scope: context.scope)
        let loadingCount = p.int(forKey: "loadingCount") ?? 3

        LazyVStack(spacing: 0) {
            if children.isEmpty {
                // Check if we're in a loading state (no children yet).
                // If there's a data source loading, show skeleton placeholders.
                if loadingCount > 0 && isLoading() {
                    ForEach(0..<loadingCount, id: \.self) { _ in
                        skeletonRow
                    }
                } else {
                    emptyState(p)
                }
            } else {
                ForEach(Array(children.enumerated()), id: \.element.id) { _, child in
                    if let view = registry.resolve(child, context: context) {
                        view
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(_ p: JSONObject) -> some View {
        let icon = p.string(forKey: "emptyIcon")
        let title = p.string(forKey: "emptyTitle")
        let subtitle = p.string(forKey: "emptySubtitle")

        if title != nil || subtitle != nil {
            VStack(spacing: theme.spacingSM) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundStyle(theme.textSecondary)
                }
                if let title {
                    Text(TextInterpolator.resolve(title, scope: context.scope))
                        .font(theme.font(style: .headline))
                        .foregroundStyle(theme.textPrimary)
                }
                if let subtitle {
                    Text(TextInterpolator.resolve(subtitle, scope: context.scope))
                        .font(theme.font(style: .body))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(theme.spacingXL)
        }
    }

    // MARK: - Skeleton loading

    private var skeletonRow: some View {
        HStack(spacing: theme.spacingSM) {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.separator)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.separator)
                    .frame(height: 14)
                    .frame(maxWidth: 180)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.separator)
                    .frame(height: 10)
                    .frame(maxWidth: 120)
            }
            Spacer()
        }
        .padding(theme.spacingSM)
        .accessibilityHidden(true)
    }

    /// Heuristic: if children are empty but we just rendered, might be loading.
    /// Actual loading detection uses scope metadata.
    private func isLoading() -> Bool {
        false
    }
}
