// InterpolationConformanceTests.swift
// Conformance tests for text interpolation ({{path}} patterns).
// Loads interpolation/basic.json and interpolation/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Interpolation Conformance")
struct InterpolationConformanceTests {

    @Test("interpolation/basic.json")
    func basicInterpolation() throws {
        let cases = try ConformanceLoader.loadSuite(category: "interpolation", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let template = testCase["template"] as! String
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expected = testCase["expected"] as! String

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let result = TextInterpolator.resolve(template, scope: scope)

            #expect(result == expected, "FAIL: \(description) — got \"\(result)\", expected \"\(expected)\"")
        }
    }

    @Test("interpolation/edge-cases.json")
    func edgeCaseInterpolation() throws {
        let cases = try ConformanceLoader.loadSuite(category: "interpolation", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let template = testCase["template"] as! String
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expected = testCase["expected"] as! String

            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let result = TextInterpolator.resolve(template, scope: scope)

            #expect(result == expected, "FAIL: \(description) — got \"\(result)\", expected \"\(expected)\"")
        }
    }
}
