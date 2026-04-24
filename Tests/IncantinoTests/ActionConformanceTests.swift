// ActionConformanceTests.swift
// Conformance tests for action guard evaluation.
// Loads actions/basic.json and actions/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Action Conformance")
struct ActionConformanceTests {

    @Test("actions/basic.json")
    func basicActions() throws {
        let cases = try ConformanceLoader.loadSuite(category: "actions", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let actionDict = testCase["action"] as! [String: Any]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedDispatched = testCase["expectedDispatched"] as! Bool

            // Extract the guard expression from the action spec.
            // "guard" can be absent (nil), null, empty string, or a real expression.
            let guardExpr: String?
            if let g = actionDict["guard"] as? String {
                guardExpr = g
            } else {
                guardExpr = nil
            }

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            // An action is dispatched when its guard evaluates to true
            // (nil/empty guard = always dispatched, matching evaluate() semantics).
            let dispatched = evaluate(expression: guardExpr, scope: scope)

            #expect(
                dispatched == expectedDispatched,
                "FAIL: \(description) — got dispatched=\(dispatched), expected \(expectedDispatched)"
            )
        }
    }

    @Test("actions/edge-cases.json")
    func edgeCaseActions() throws {
        let cases = try ConformanceLoader.loadSuite(category: "actions", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let actionDict = testCase["action"] as! [String: Any]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedDispatched = testCase["expectedDispatched"] as! Bool

            let guardExpr: String?
            if let g = actionDict["guard"] as? String {
                guardExpr = g
            } else {
                guardExpr = nil
            }

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let dispatched = evaluate(expression: guardExpr, scope: scope)

            #expect(
                dispatched == expectedDispatched,
                "FAIL: \(description) — got dispatched=\(dispatched), expected \(expectedDispatched)"
            )
        }
    }
}
