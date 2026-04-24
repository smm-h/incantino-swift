// ScopeConformanceTests.swift
// Conformance tests for scope resolution and parent chain delegation.
// Loads scopes/basic.json and scopes/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Scope Conformance")
struct ScopeConformanceTests {

    /// Build a scope chain from the conformance "scopes" array.
    /// Each entry has "values" and an optional "parent" index.
    /// Returns the array of built scopes so the caller can pick resolveFrom.
    private func buildScopeChain(from scopesDef: [[String: Any]]) -> [DictionaryScope] {
        var scopes: [DictionaryScope] = []

        for scopeDef in scopesDef {
            let values = scopeDef["values"] as? [String: Any] ?? [:]
            let parentIndex = scopeDef["parent"] as? Int

            let parent: DictionaryScope? = parentIndex.flatMap { idx in
                idx < scopes.count ? scopes[idx] : nil
            }

            let scope = DictionaryScope(parent: parent)
            for (key, val) in values {
                scope.set(key, value: ConformanceLoader.scopeValue(from: val))
            }
            scopes.append(scope)
        }

        return scopes
    }

    @Test("scopes/basic.json")
    func basicScopes() throws {
        let cases = try ConformanceLoader.loadSuite(category: "scopes", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let scopesDef = testCase["scopes"] as! [[String: Any]]
            let resolveFrom = testCase["resolveFrom"] as! Int
            let path = testCase["path"] as! String
            let expected = testCase["expected"] as! [String: Any]

            let scopes = buildScopeChain(from: scopesDef)
            let scope = scopes[resolveFrom]
            let result = scope.resolve(path)

            let matches = ConformanceLoader.scopeValueMatches(result, expected: expected)
            #expect(matches, "FAIL: \(description) — got \(ConformanceLoader.describeScopeValue(result)), expected \(expected)")
        }
    }

    @Test("scopes/edge-cases.json")
    func edgeCaseScopes() throws {
        let cases = try ConformanceLoader.loadSuite(category: "scopes", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let scopesDef = testCase["scopes"] as! [[String: Any]]
            let resolveFrom = testCase["resolveFrom"] as! Int
            let path = testCase["path"] as! String
            let expected = testCase["expected"] as! [String: Any]

            let scopes = buildScopeChain(from: scopesDef)
            let scope = scopes[resolveFrom]
            let result = scope.resolve(path)

            let matches = ConformanceLoader.scopeValueMatches(result, expected: expected)
            #expect(matches, "FAIL: \(description) — got \(ConformanceLoader.describeScopeValue(result)), expected \(expected)")
        }
    }
}
