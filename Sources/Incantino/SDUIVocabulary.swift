// SDUIVocabulary.swift
// Known component types, action types, and navigation targets for validation.

import Foundation

/// A vocabulary of known SDUI identifiers used by the config validator
/// to check for unknown component types, action types, and navigate targets.
public struct SDUIVocabulary: Codable, Sendable {
    public let componentTypes: Set<String>
    public let actionTypes: Set<String>
    public let navigationTargets: Set<String>
    public let sheetIds: Set<String>

    public init(
        componentTypes: Set<String>,
        actionTypes: Set<String>,
        navigationTargets: Set<String>,
        sheetIds: Set<String>
    ) {
        self.componentTypes = componentTypes
        self.actionTypes = actionTypes
        self.navigationTargets = navigationTargets
        self.sheetIds = sheetIds
    }

    /// Load a vocabulary from a JSON file.
    public static func load(from url: URL) throws -> SDUIVocabulary {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SDUIVocabulary.self, from: data)
    }
}
