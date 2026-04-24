// TextComponent.swift
// Styled text with scope interpolation.

import SwiftUI

public struct TextComponent: IncantinoComponent {
    public static let typeName = "text"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let rawText = p.string(forKey: "text") ?? ""
        let interpolated = TextInterpolator.resolve(rawText, scope: context.scope)
        let style = TypographyStyle(rawValue: p.string(forKey: "style") ?? "body") ?? .body
        let alignment = textAlignment(from: p.string(forKey: "alignment"))
        let lineLimit = p.int(forKey: "lineLimit")
        let decoration = p.string(forKey: "decoration") ?? "none"
        let color = resolveColor(p.string(forKey: "color"), theme: theme)

        var text = Text(interpolated)
            .font(theme.font(style: style))
            .foregroundStyle(color)

        // Apply decoration.
        if decoration == "strikethrough" {
            text = text.strikethrough()
        } else if decoration == "underline" {
            text = text.underline()
        }

        return text
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: frameAlignment(from: p.string(forKey: "alignment")))
            // Heading styles get accessibility header trait.
            .accessibilityAddTraits(isHeading(style) ? .isHeader : [])
    }

    private func isHeading(_ style: TypographyStyle) -> Bool {
        switch style {
        case .largeTitle, .title, .headline: true
        default: false
        }
    }

    private func textAlignment(from value: String?) -> TextAlignment {
        switch value {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    private func frameAlignment(from value: String?) -> Alignment {
        switch value {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }
}

// MARK: - Color resolution helper

/// Resolve a color string to a SwiftUI Color.
/// Supports theme token names and hex strings.
func resolveColor(_ value: String?, theme: any ThemeReading) -> Color {
    guard let value, !value.isEmpty else { return theme.textPrimary }

    // Theme token names.
    switch value {
    case "background": return theme.background
    case "surface": return theme.surface
    case "surfaceElevated": return theme.surfaceElevated
    case "accent": return theme.accent
    case "accentSecondary": return theme.accentSecondary
    case "textPrimary": return theme.textPrimary
    case "textSecondary": return theme.textSecondary
    case "separator": return theme.separator
    case "error": return theme.error
    case "success": return theme.success
    case "transit": return theme.transit
    default: break
    }

    // Hex color (e.g. "#FF0000" or "FF0000").
    let hex = value.hasPrefix("#") ? String(value.dropFirst()) : value
    guard hex.count == 6, let rgb = UInt(hex, radix: 16) else {
        return theme.textPrimary
    }
    return Color(
        red: Double((rgb >> 16) & 0xFF) / 255,
        green: Double((rgb >> 8) & 0xFF) / 255,
        blue: Double(rgb & 0xFF) / 255
    )
}
