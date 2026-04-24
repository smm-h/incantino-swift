// ComponentRegistration.swift
// Registers all 25 standard Incantino components with the shared registry.
// Call this once at engine startup before rendering any screens.

import SwiftUI

/// Register all 25 standard components with the shared ComponentRegistry.
@MainActor
public func registerStandardComponents(registry: ComponentRegistry = .shared) {
    // Layout (5)
    registry.register(VStackComponent.self)
    registry.register(HStackComponent.self)
    registry.register(RowComponent.self)
    registry.register(GridComponent.self)
    registry.register(ScrollComponent.self)

    // Content (5)
    registry.register(TextComponent.self)
    registry.register(ImageComponent.self)
    registry.register(IconComponent.self)
    registry.register(SpacerComponent.self)
    registry.register(DividerComponent.self)

    // Interactive (8)
    registry.register(ButtonComponent.self)
    registry.register(InputComponent.self)
    registry.register(SelectComponent.self)
    registry.register(ToggleComponent.self)
    registry.register(CheckboxComponent.self)
    registry.register(SliderComponent.self)
    registry.register(AccordionComponent.self)
    registry.register(TabsComponent.self)

    // Data display (4)
    registry.register(CardComponent.self)
    registry.register(BadgeComponent.self)
    registry.register(ListComponent.self)
    registry.register(TimelineComponent.self)

    // Containers (2)
    registry.register(SheetComponent.self)
    registry.register(DialogComponent.self)

    // Flow (1)
    registry.register(FlowComponent.self)
}
