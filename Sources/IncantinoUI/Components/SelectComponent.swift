// SelectComponent.swift
// Card-based picker supporting single and multi selection modes.
// Options are rendered as tappable cards; selected options are visually highlighted.

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
        let options = extractOptions(from: p)
        let label = p.string(forKey: "label")

        VStack(alignment: .leading, spacing: theme.spacingSM) {
            if let label {
                Text(TextInterpolator.resolve(label, scope: context.scope))
                    .font(theme.font(style: .subheadline))
                    .foregroundStyle(theme.textSecondary)
            }

            ForEach(options, id: \.id) { option in
                optionCard(option: option, isMulti: mode == "multi")
            }
        }
        .onAppear {
            loadInitialSelection()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "")
    }

    // MARK: - Option card

    @ViewBuilder
    private func optionCard(option: SelectOption, isMulti: Bool) -> some View {
        let isSelected = selected.contains(option.id)

        Button {
            if isMulti {
                if isSelected {
                    selected.remove(option.id)
                } else {
                    selected.insert(option.id)
                }
            } else {
                selected = [option.id]
            }
            writeToScope()
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

        if let scope = context.scope as? FormScope {
            if mode == "single" {
                scope.set(binding, value: .text(selected.first ?? ""))
            } else {
                scope.set(binding, value: .selection(selected))
            }
        } else if let scope = context.scope as? DictionaryScope {
            if mode == "single" {
                scope.set(binding, value: .text(selected.first ?? ""))
            } else {
                scope.set(binding, value: .selection(selected))
            }
        }
    }
}
