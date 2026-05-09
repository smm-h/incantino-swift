// SelectComponent.swift
// Card-based picker supporting single and multi selection modes.
// Options are rendered as tappable cards; selected options are visually highlighted.
// Supports three display modes: list (default vertical cards), grid (3-column compact),
// and cards (2-column with gradient fill).

import SwiftUI

public struct SelectComponent: IncantinoComponent {
    public static let typeName = "select"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @State private var selected: Set<String> = []

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let mode = p.string(forKey: "mode") ?? "single"
        let displayMode = p.string(forKey: "displayMode") ?? "list"
        let options = extractOptions(from: p)
        let label = p.string(forKey: "label")

        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let label {
                Text(TextInterpolator.resolve(label, scope: context.scope))
                    .font(theme.font(style: .subheadline))
                    .foregroundStyle(theme.textSecondary)
            }

            switch displayMode {
            case "grid":
                gridLayout(options: options, isMulti: mode == "multi")
            case "cards":
                cardsLayout(options: options, isMulti: mode == "multi")
            default:
                listLayout(options: options, isMulti: mode == "multi")
            }
        }
        .onAppear {
            loadInitialSelection()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "")
    }

    // MARK: - List layout (default)

    @ViewBuilder
    private func listLayout(options: [SelectOption], isMulti: Bool) -> some View {
        ForEach(options, id: \.id) { option in
            listOptionCard(option: option, isMulti: isMulti)
        }
    }

    @ViewBuilder
    private func listOptionCard(option: SelectOption, isMulti: Bool) -> some View {
        let isSelected = selected.contains(option.id)

        Button {
            toggleSelection(option: option, isMulti: isMulti)
        } label: {
            HStack(spacing: theme.spacingSM) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(theme.font(style: .body))
                        .foregroundStyle(theme.textPrimary)
                    if let desc = option.description {
                        Text(desc)
                            .font(theme.font(style: .caption))
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(theme.spacingSM)
            .background(isSelected ? theme.accent.opacity(0.1) : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(isSelected ? theme.accent : theme.separator, lineWidth: 1)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Grid layout (3 columns, compact cells)

    private static let gridColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    @ViewBuilder
    private func gridLayout(options: [SelectOption], isMulti: Bool) -> some View {
        LazyVGrid(columns: Self.gridColumns, spacing: theme.spacingSM) {
            ForEach(options, id: \.id) { option in
                gridCell(option: option, isMulti: isMulti)
            }
        }
    }

    @ViewBuilder
    private func gridCell(option: SelectOption, isMulti: Bool) -> some View {
        let isSelected = selected.contains(option.id)

        Button {
            toggleSelection(option: option, isMulti: isMulti)
        } label: {
            VStack(spacing: theme.spacingXS) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(theme.font(style: .title))
                        .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                }

                Text(option.label)
                    .font(theme.font(style: .caption))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingSM)
            .padding(.horizontal, theme.spacingXS)
            .background(isSelected ? theme.accent.opacity(0.1) : theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: theme.cardSmallCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardSmallCornerRadius)
                    .strokeBorder(isSelected ? theme.accent : theme.separator, lineWidth: 1)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Cards layout (2 columns, taller with gradient fill)

    private static let cardsColumns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    @ViewBuilder
    private func cardsLayout(options: [SelectOption], isMulti: Bool) -> some View {
        LazyVGrid(columns: Self.cardsColumns, spacing: theme.spacingSM) {
            ForEach(options, id: \.id) { option in
                cardCell(option: option, isMulti: isMulti)
            }
        }
    }

    @ViewBuilder
    private func cardCell(option: SelectOption, isMulti: Bool) -> some View {
        let isSelected = selected.contains(option.id)

        Button {
            toggleSelection(option: option, isMulti: isMulti)
        } label: {
            VStack(spacing: theme.spacingSM) {
                if let icon = option.icon {
                    Image(systemName: icon)
                        .font(theme.font(style: .largeTitle))
                        .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                }

                Text(option.label)
                    .font(theme.font(style: .body))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .padding(theme.spacingSM)
            .background(
                isSelected
                    ? theme.accent.opacity(0.15)
                    : theme.surface
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                    .strokeBorder(isSelected ? theme.accent : theme.separator, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.accent)
                        .padding(theme.spacingXS)
                }
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Selection logic (shared across all display modes)

    private func toggleSelection(option: SelectOption, isMulti: Bool) {
        let isSelected = selected.contains(option.id)
        if isMulti {
            if isSelected {
                selected.remove(option.id)
            } else {
                selected.insert(option.id)
            }
        } else {
            selected = [option.id]
        }
        HapticManager.light()
        writeToScope()
        dispatchOnSelect()
    }

    private func dispatchOnSelect() {
        guard let action = spec.action else { return }
        let dispatcher = context.dispatch
        let scope = context.scope
        Task { @MainActor in
            await dispatcher.dispatch(action, scope: scope, screenActions: context.screenActions)
        }
    }

    // MARK: - Option extraction

    private struct SelectOption: Identifiable {
        let id: String
        let label: String
        let icon: String?
        let description: String?
    }

    private func extractOptions(from p: JSONObject) -> [SelectOption] {
        guard let arr = p.array(forKey: "options") else { return [] }
        return arr.compactMap { item in
            guard case .object(let obj) = item,
                  let id = obj.string(forKey: "id"),
                  let label = obj.string(forKey: "label") else { return nil }
            return SelectOption(
                id: id,
                label: label,
                icon: obj.string(forKey: "icon"),
                description: obj.string(forKey: "description")
            )
        }
    }

    // MARK: - Scope binding

    private func loadInitialSelection() {
        guard let binding = spec.effectiveBinding else { return }
        let value = context.scope.resolve(binding)
        switch value {
        case .text(let s) where !s.isEmpty:
            selected = [s]
        case .selection(let s):
            selected = s
        default:
            break
        }
    }

    private func writeToScope() {
        guard let binding = spec.effectiveBinding else { return }
        let p = spec.properties ?? [:]
        let mode = p.string(forKey: "mode") ?? "single"

        if mode == "single" {
            context.writeToScope(binding, value: .text(selected.first ?? ""))
        } else {
            context.writeToScope(binding, value: .selection(selected))
        }
    }
}
