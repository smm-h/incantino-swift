// InputComponent.swift
// Text input field with variants (text, email, phone, number, search).
// Binds to FormScope via the section's binding path.

import SwiftUI

public struct InputComponent: IncantinoComponent {
    public static let typeName = "input"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme
    @State private var text: String = ""

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let variant = p.string(forKey: "variant") ?? "text"
        let placeholder = TextInterpolator.resolve(
            p.string(forKey: "placeholder") ?? "", scope: context.scope
        )
        let label = p.string(forKey: "label")

        VStack(alignment: .leading, spacing: theme.spacingXS) {
            if let label {
                Text(label)
                    .font(theme.font(style: .caption))
                    .foregroundStyle(theme.textSecondary)
            }

            textField(variant: variant, placeholder: placeholder)
                .font(theme.font(style: .body))
                .textFieldStyle(.plain)
                .padding(theme.spacingSM)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.buttonCornerRadius)
                        .strokeBorder(theme.separator, lineWidth: 1)
                )
                .accessibilityLabel(label ?? placeholder)

            // Show validation error if present.
            if let binding = spec.effectiveBinding,
               let formScope = context.scope as? FormScope,
               let error = formScope.errors[binding] {
                Text(error)
                    .font(theme.font(style: .caption))
                    .foregroundStyle(theme.error)
            }
        }
        .onAppear {
            loadInitialValue()
        }
        .onChange(of: text) { _, newValue in
            writeToScope(newValue)
        }
    }

    // MARK: - Variant-specific TextField

    @ViewBuilder
    private func textField(variant: String, placeholder: String) -> some View {
        switch variant {
        case "email":
            TextField(placeholder, text: $text)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        case "phone":
            TextField(placeholder, text: $text)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        case "number":
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
        case "search":
            TextField(
                placeholder.isEmpty
                    ? IncantinoStrings.shared.resolve(.searchPlaceholder)
                    : placeholder,
                text: $text
            )
            .textContentType(.none)
            .autocorrectionDisabled()
        default:
            TextField(placeholder, text: $text)
        }
    }

    // MARK: - Scope binding

    private func loadInitialValue() {
        guard let binding = spec.effectiveBinding else { return }
        let current = context.scope.resolve(binding)
        if let str = current.stringValue {
            text = str
        } else if let prefillPath = (spec.properties ?? [:]).string(forKey: "prefill") {
            let prefill = context.scope.resolve(prefillPath)
            if let str = prefill.stringValue {
                text = str
            }
        }
    }

    private func writeToScope(_ value: String) {
        guard let binding = spec.effectiveBinding else { return }
        if let scope = context.scope as? FormScope {
            scope.set(binding, value: .text(value))
        } else if let scope = context.scope as? DictionaryScope {
            scope.set(binding, value: .text(value))
        }
    }
}
