// IncantinoLocalization.swift
// Engine string localization with 16 keys and English defaults.
// Apps provide locale-specific overrides via a custom StringResolving implementation.

import Foundation

// MARK: - StringKey

/// The 16 engine string keys organized by category.
public enum StringKey: String, CaseIterable, Sendable {
    // Flow navigation (2)
    case flowBack = "incantino.flow.back"
    case flowScreenNotFound = "incantino.flow.screenNotFound"

    // Action feedback (4)
    case actionSubmitUnavailable = "incantino.action.submit.unavailable"
    case actionSubmitPlaceholder = "incantino.action.submit.placeholder"
    case actionRefreshUnavailable = "incantino.action.refresh.unavailable"
    case actionInvokeUnavailable = "incantino.action.invoke.unavailable"

    // Pill accessibility (5)
    case pillAccessibilityLabel = "incantino.pill.accessibilityLabel"
    case pillAccessibilityHintOpen = "incantino.pill.accessibilityHint.open"
    case pillPlaceholder = "incantino.pill.placeholder"
    case pillThinking = "incantino.pill.thinking"
    case pillAccessibilityHintProceed = "incantino.pill.accessibilityHint.proceed"

    // Chip accessibility (3)
    case chipHintNavigate = "incantino.chip.hint.navigate"
    case chipHintMessage = "incantino.chip.hint.message"
    case chipHintAction = "incantino.chip.hint.action"

    // Component defaults (2)
    case searchPlaceholder = "incantino.search.placeholder"
    case pickerConfirm = "incantino.picker.confirm"
}

// MARK: - English defaults

extension StringKey {
    /// The English default for this key.
    public var englishDefault: String {
        switch self {
        case .flowBack: "Back"
        case .flowScreenNotFound: "Screen not found"
        case .actionSubmitUnavailable: "Submission not available"
        case .actionSubmitPlaceholder: "Coming soon"
        case .actionRefreshUnavailable: "Refresh not yet available"
        case .actionInvokeUnavailable: "Function '%s' not yet available"
        case .pillAccessibilityLabel: "Assistant"
        case .pillAccessibilityHintOpen: "Tap to open"
        case .pillPlaceholder: "Ask me anything..."
        case .pillThinking: "Thinking"
        case .pillAccessibilityHintProceed: "Tap to proceed"
        case .chipHintNavigate: "Tap to open"
        case .chipHintMessage: "Tap to send"
        case .chipHintAction: "Tap to execute"
        case .searchPlaceholder: "Search..."
        case .pickerConfirm: "Confirm"
        }
    }
}

// MARK: - StringResolving

/// Protocol for resolving engine strings. Apps override for localization.
public protocol StringResolving: Sendable {
    func resolve(_ key: StringKey) -> String
}

// MARK: - DefaultStringResolver

/// Returns English defaults for all keys.
public struct DefaultStringResolver: StringResolving {
    public init() {}

    public func resolve(_ key: StringKey) -> String {
        key.englishDefault
    }
}

// MARK: - IncantinoStrings

/// Shared string resolver instance. Apps replace with a localized resolver.
public final class IncantinoStrings: @unchecked Sendable {
    public static let shared = IncantinoStrings()

    private let lock = NSLock()
    private var _resolver: any StringResolving = DefaultStringResolver()

    private init() {}

    /// The current resolver.
    public var resolver: any StringResolving {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _resolver
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _resolver = newValue
        }
    }

    /// Resolve a string key using the current resolver.
    public func resolve(_ key: StringKey) -> String {
        resolver.resolve(key)
    }

    /// Resolve actionInvokeUnavailable with the method name substituted for %s.
    public func resolveInvoke(methodName: String) -> String {
        resolve(.actionInvokeUnavailable).replacingOccurrences(of: "%s", with: methodName)
    }
}
