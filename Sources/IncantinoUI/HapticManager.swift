#if canImport(UIKit)
import UIKit

/// Convenience wrapper around UIKit haptic feedback generators.
public enum HapticManager: Sendable {
    @MainActor public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @MainActor public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @MainActor public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
#else
/// macOS fallback -- no haptic hardware available.
public enum HapticManager: Sendable {
    @MainActor public static func light() {}
    @MainActor public static func medium() {}
    @MainActor public static func success() {}
    @MainActor public static func error() {}
}
#endif
