// ExpressionConformanceTests.swift
// Conformance tests for the expression evaluator.
// Loads expressions/basic.json and expressions/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Expression Conformance")
struct ExpressionConformanceTests {

    @Test("expressions/basic.json")
    func basicExpressions() throws {
        let cases = try ConformanceLoader.loadSuite(category: "expressions", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            // expression can be null (nil), string, or absent
            let expression: String?
            if let expr = testCase["expression"] as? String {
                expression = expr
            } else if testCase["expression"] is NSNull || testCase["expression"] == nil {
                expression = nil
            } else {
                expression = nil
            }
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expected = testCase["expected"] as! Bool

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let result = evaluate(expression: expression, scope: scope)

            #expect(result == expected, "FAIL: \(description) — got \(result), expected \(expected)")
        }
    }

    @Test("expressions/edge-cases.json")
    func edgeCaseExpressions() throws {
        let cases = try ConformanceLoader.loadSuite(category: "expressions", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let expression: String?
            if let expr = testCase["expression"] as? String {
                expression = expr
            } else if testCase["expression"] is NSNull || testCase["expression"] == nil {
                expression = nil
            } else {
                expression = nil
            }
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expected = testCase["expected"] as! Bool

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let result = evaluate(expression: expression, scope: scope)

            #expect(result == expected, "FAIL: \(description) — got \(result), expected \(expected)")
        }
    }
}
