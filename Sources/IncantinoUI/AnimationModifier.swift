// AnimationModifier.swift
// Generic section-level animation support for SDUI sections.
// Reads AnimationSpec from SectionSpec and applies entry (on appear) and
// press (on tap) animations. No-op when animation is nil.

import SwiftUI
import Incantino

#if canImport(UIKit)
import UIKit
#endif

// MARK: - AnimationModifier

/// A ViewModifier that applies entry and press animations from an AnimationSpec.
/// When `animation` is nil, the modifier is a transparent pass-through (no overhead).
///
/// Entry animations fire once when the view appears. Press animations provide
/// tap feedback (the view must already handle its own tap action; this modifier
/// only adds the visual effect via a simultaneous gesture).
///
/// Respects `UIAccessibility.isReduceMotionEnabled` -- when true, all animations
/// are skipped and content appears instantly.
struct AnimationModifier: ViewModifier {
    let animation: AnimationSpec?
    let siblingIndex: Int
    let theme: any ThemeReading

    // Entry state
    @State private var hasAppeared = false
    // Press state
    @State private var isPressed = false

    func body(content: Content) -> some View {
        if let animation {
            animatedContent(content, spec: animation)
        } else {
            content
        }
    }

    @ViewBuilder
    private func animatedContent(_ content: Content, spec: AnimationSpec) -> some View {
        let reduceMotion = Self.reduceMotionEnabled

        content
            // Entry animation transforms
            .opacity(entryOpacity(spec: spec, reduceMotion: reduceMotion))
            .offset(y: entryOffsetY(spec: spec, reduceMotion: reduceMotion))
            .offset(x: entryOffsetX(spec: spec, reduceMotion: reduceMotion))
            .scaleEffect(entryScale(spec: spec, reduceMotion: reduceMotion))
            // Press animation transforms
            .scaleEffect(pressScale(spec: spec, reduceMotion: reduceMotion))
            .opacity(pressOpacity(spec: spec, reduceMotion: reduceMotion))
            // Press gesture (only if press animation is specified)
            .applyIf(spec.press != nil && !reduceMotion) { view in
                view.simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed {
                                withAnimation(.easeInOut(duration: theme.animationFast)) {
                                    isPressed = true
                                }
                            }
                        }
                        .onEnded { _ in
                            withAnimation(pressReleaseAnimation(spec: spec)) {
                                isPressed = false
                            }
                        }
                )
            }
            // Trigger entry animation on appear
            .onAppear {
                guard !reduceMotion, !hasAppeared else {
                    hasAppeared = true
                    return
                }
                withAnimation(entryAnimation(spec: spec)) {
                    hasAppeared = true
                }
            }
    }

    // MARK: - Reduce Motion

    private static var reduceMotionEnabled: Bool {
        #if canImport(UIKit)
        UIAccessibility.isReduceMotionEnabled
        #else
        false
        #endif
    }

    // MARK: - Entry Animation Values

    private func entryOpacity(spec: AnimationSpec, reduceMotion: Bool) -> Double {
        guard !reduceMotion, !hasAppeared else { return 1.0 }
        switch spec.entry {
        case "fadeIn", "slideUp", "slideDown", "slideLeft", "slideRight", "scaleIn", "stagger":
            return 0.0
        default:
            return 1.0
        }
    }

    private func entryOffsetY(spec: AnimationSpec, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, !hasAppeared else { return 0 }
        switch spec.entry {
        case "slideUp", "stagger":
            return 20
        case "slideDown":
            return -20
        default:
            return 0
        }
    }

    private func entryOffsetX(spec: AnimationSpec, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, !hasAppeared else { return 0 }
        switch spec.entry {
        case "slideLeft":
            return 20
        case "slideRight":
            return -20
        default:
            return 0
        }
    }

    private func entryScale(spec: AnimationSpec, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, !hasAppeared else { return 1.0 }
        switch spec.entry {
        case "scaleIn":
            return 0.8
        default:
            return 1.0
        }
    }

    // MARK: - Entry Animation Timing

    private func entryAnimation(spec: AnimationSpec) -> Animation {
        let baseDuration: Double
        switch spec.entry {
        case "fadeIn", "slideUp", "slideDown", "slideLeft", "slideRight", "scaleIn", "stagger":
            baseDuration = theme.animationStandard
        default:
            baseDuration = theme.animationStandard
        }

        var anim = Animation.easeOut(duration: baseDuration)

        // Stagger: apply delay based on sibling index
        if spec.entry == "stagger" {
            let staggerInterval = 0.06
            anim = anim.delay(Double(siblingIndex) * staggerInterval)
        }

        return anim
    }

    // MARK: - Press Animation Values

    private func pressScale(spec: AnimationSpec, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, isPressed else { return 1.0 }
        switch spec.press {
        case "press", "scale":
            return 0.95
        case "bounce":
            return 0.92
        default:
            return 1.0
        }
    }

    private func pressOpacity(spec: AnimationSpec, reduceMotion: Bool) -> Double {
        guard !reduceMotion, isPressed else { return 1.0 }
        switch spec.press {
        case "opacity":
            return 0.7
        default:
            return 1.0
        }
    }

    private func pressReleaseAnimation(spec: AnimationSpec) -> Animation {
        switch spec.press {
        case "bounce":
            return .spring(response: 0.3, dampingFraction: 0.5)
        default:
            return .easeInOut(duration: theme.animationFast)
        }
    }
}

// MARK: - Conditional modifier helper

private extension View {
    @ViewBuilder
    func applyIf<V: View>(_ condition: Bool, transform: (Self) -> V) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - View extension

extension View {
    /// Apply section-level animation from an AnimationSpec.
    /// No-op when `animation` is nil -- zero performance cost for non-animated sections.
    public func sectionAnimation(
        _ animation: AnimationSpec?,
        siblingIndex: Int = 0,
        theme: any ThemeReading
    ) -> some View {
        modifier(AnimationModifier(
            animation: animation,
            siblingIndex: siblingIndex,
            theme: theme
        ))
    }
}
