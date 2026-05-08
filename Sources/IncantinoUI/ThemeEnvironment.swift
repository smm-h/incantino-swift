import SwiftUI

/// Environment key for injecting a theme into the SwiftUI view hierarchy.
struct ThemeKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: any ThemeReading = DefaultTheme()
}

extension EnvironmentValues {
    public var theme: any ThemeReading {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
