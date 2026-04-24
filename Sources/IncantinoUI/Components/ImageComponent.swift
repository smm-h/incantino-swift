// ImageComponent.swift
// Async image with shape clipping and accessibility.

import SwiftUI

public struct ImageComponent: IncantinoComponent {
    public static let typeName = "image"

    let spec: SectionSpec
    let context: SDUIContext

    @Environment(\.theme) private var theme

    public init(spec: SectionSpec, context: SDUIContext) {
        self.spec = spec
        self.context = context
    }

    public var body: some View {
        let p = spec.properties ?? [:]
        let urlString = TextInterpolator.resolve(p.string(forKey: "url") ?? "", scope: context.scope)
        let alt = TextInterpolator.resolve(p.string(forKey: "alt") ?? "", scope: context.scope)
        let shape = p.string(forKey: "shape") ?? "rectangle"
        let cornerRadius = p.double(forKey: "cornerRadius") ?? 8
        let isHidden = p.bool(forKey: "accessibilityHidden") ?? false
        let fill = p.string(forKey: "fill") ?? "fit"
        let size = p.double(forKey: "size")
        let aspectRatio = p.double(forKey: "aspectRatio")

        AsyncImage(url: URL(string: urlString)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: fill == "fill" ? .fill : .fit)
            case .failure:
                // Show a placeholder icon on failure.
                Image(systemName: "photo")
                    .foregroundStyle(theme.textSecondary)
            case .empty:
                // Loading placeholder.
                ProgressView()
            @unknown default:
                EmptyView()
            }
        }
        .applySize(size)
        .applyAspectRatio(aspectRatio)
        .applyImageShape(shape, cornerRadius: cornerRadius)
        .accessibilityLabel(alt)
        .accessibilityHidden(isHidden)
    }
}

// MARK: - Shape clipping

private extension View {
    @ViewBuilder
    func applyImageShape(_ shape: String, cornerRadius: Double) -> some View {
        switch shape {
        case "circle":
            self.clipShape(Circle())
        case "rounded":
            self.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        default:
            self
        }
    }

    @ViewBuilder
    func applySize(_ size: Double?) -> some View {
        if let size {
            self.frame(width: size, height: size)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyAspectRatio(_ ratio: Double?) -> some View {
        if let ratio {
            self.aspectRatio(ratio, contentMode: .fit)
        } else {
            self
        }
    }
}
