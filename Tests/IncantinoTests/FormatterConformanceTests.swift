// FormatterConformanceTests.swift
// Conformance tests for the formatter pipe system.
// Loads formatters/basic.json and formatters/edge-cases.json.
// Formatters are tested through interpolation (template + scope -> expected string).

import Testing
import Foundation
@testable import Incantino

@Suite("Formatter Conformance")
struct FormatterConformanceTests {

    @Test("formatters/basic.json")
    func basicFormatters() throws {
        let cases = try ConformanceLoader.loadSuite(category: "formatters", name: "basic")

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

    @Test("formatters/edge-cases.json")
    func edgeCaseFormatters() throws {
        let cases = try ConformanceLoader.loadSuite(category: "formatters", name: "edge-cases")

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
