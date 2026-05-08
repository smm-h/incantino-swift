// ListComponent.swift
// Vertical list with loading and empty state support.
// Supports two modes: static children (no dataSource) and data-driven
// iteration (with dataSource) where a template slot is rendered per item.

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

        if let dataSourcePath = p.string(forKey: "dataSource") {
            dataDrivenBody(dataSourcePath: dataSourcePath, p: p)
        } else {
            staticBody(p: p)
        }
    }

    // MARK: - Static children mode (no dataSource)

    @ViewBuilder
    private func staticBody(p: JSONObject) -> some View {
        let children = (spec.children ?? []).visible(scope: context.scope)
        let loadingCount = p.int(forKey: "loadingCount") ?? 3

        LazyVStack(spacing: 0) {
            if children.isEmpty {
                if loadingCount > 0 && isLoading(dataSourcePath: nil) {
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

    // MARK: - Data-driven mode (with dataSource)

    @ViewBuilder
    private func dataDrivenBody(dataSourcePath: String, p: JSONObject) -> some View {
        let loadingCount = p.int(forKey: "loadingCount") ?? 3
        let itemVariable = p.string(forKey: "itemVariable") ?? "item"
        let templateSpec = spec.slots?["template"]?.first

        LazyVStack(spacing: 0) {
            if isLoading(dataSourcePath: dataSourcePath) {
                // Loading: show skeleton placeholders.
                ForEach(0..<loadingCount, id: \.self) { _ in
                    skeletonRow
                }
            } else {
                let items = resolveDataSource(path: dataSourcePath)
                if items.isEmpty {
                    emptyState(p)
                } else if let templateSpec {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, jsonItem in
                        let itemScope = makeItemScope(
                            item: jsonItem,
                            index: index,
                            lastIndex: items.count - 1,
                            itemVariable: itemVariable
                        )
                        let itemContext = SDUIContext(
                            scope: itemScope,
                            dispatch: context.dispatch,
                            theme: context.theme,
                            screenActions: context.screenActions
                        )
                        if let view = registry.resolve(templateSpec, context: itemContext) {
                            view
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data source resolution

    /// Resolve the dataSource path from scope and extract a filtered array
    /// of non-null JSON values.
    private func resolveDataSource(path: String) -> [JSONValue] {
        let resolved = context.scope.resolve(path)
        guard case .json(let jsonVal) = resolved,
              case .array(let arr) = jsonVal else {
            return []
        }
        // Filter out null entries.
        return arr.filter { !$0.isNull }
    }

    /// Build a DictionaryScope for a single item with iteration metadata.
    private func makeItemScope(
        item: JSONValue,
        index: Int,
        lastIndex: Int,
        itemVariable: String
    ) -> DictionaryScope {
        let scope = DictionaryScope(
            values: [
                itemVariable: .json(item),
                "\(itemVariable).$index": .json(.int(index)),
                "\(itemVariable).$isFirst": .json(.bool(index == 0)),
                "\(itemVariable).$isLast": .json(.bool(index == lastIndex)),
            ],
            parent: context.scope
        )
        return scope
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

    /// Check if the data source is currently loading via scope metadata.
    /// For data-driven mode, checks `$data.<name>.isLoading`.
    /// For static mode (no dataSource path), returns false.
    private func isLoading(dataSourcePath: String?) -> Bool {
        guard let path = dataSourcePath else { return false }
        // dataSourcePath is e.g. "$data.products"; loading key is "$data.products.isLoading".
        let loadingKey = "\(path).isLoading"
        return context.scope.resolve(loadingKey).isTruthy
    }
}
