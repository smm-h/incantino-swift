// IncantinoView.swift
// The main entry point for rendering Incantino screens.

import SwiftUI
import os

private let logger = Logger(subsystem: "Incantino", category: "IncantinoView")

/// The main entry point for rendering Incantino screens.
/// Use this view in your app's root or navigation stack.
///
/// **Basic usage (in-memory config for testing):**
/// ```swift
/// let provider = InMemoryConfigProvider(screens: [...])
/// IncantinoView(provider: provider)
/// ```
///
/// **Production usage (bundle + manifest):**
/// ```swift
/// IncantinoView(
///     provider: BundledConfigProvider(
///         bundleDirectory: Bundle.main.url(forResource: "config", withExtension: nil)!,
///         manifestURL: URL(string: "https://cdn.example.com/manifest.json")!
///     )
/// )
/// .incantinoTheme(SkinTheme(url: Bundle.main.url(forResource: "skin", withExtension: "json")!))
/// .incantinoScope(myAppScope)
/// ```
public struct IncantinoView: View {
    private let provider: any ConfigProviding
    @Environment(\.theme) private var theme

    public init(provider: any ConfigProviding) {
        self.provider = provider
    }

    public var body: some View {
        // Delegate to IncantinoContent which manages the loading lifecycle.
        IncantinoContent(provider: provider)
    }
}

// MARK: - IncantinoContent

/// Internal content view that manages the loading lifecycle.
/// Loads the manifest and renders the first screen via ScreenRenderer.
struct IncantinoContent: View {
    let provider: any ConfigProviding
    @State private var manifest: Manifest?
    @State private var currentScreen: ScreenSpec?
    @State private var isLoading = true
    @Environment(\.theme) private var theme
    @Environment(\.sduiScope) private var scope

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let screen = currentScreen {
                // Build a rendering context from the environment.
                let context = SDUIContext(
                    scope: scope,
                    dispatch: NoOpDispatcher(),
                    theme: theme,
                    screenActions: screen.actions ?? [:]
                )
                ScreenRenderer(screen: screen, context: context)
            } else {
                Text("No content available")
            }
        }
        .task {
            do {
                manifest = try await provider.loadManifest()
                // Load the first screen (or "home" if it exists).
                if let screens = manifest?.screens {
                    let targetId = screens.keys.contains("home")
                        ? "home"
                        : screens.keys.sorted().first
                    if let id = targetId {
                        currentScreen = try await provider.loadScreen(id: id)
                    }
                }
            } catch {
                logger.error("Failed to load config: \(error)")
            }
            isLoading = false
        }
    }
}
