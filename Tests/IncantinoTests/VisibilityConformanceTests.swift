// VisibilityConformanceTests.swift
// Conformance tests for section visibility filtering.
// Loads visibility/basic.json and visibility/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Visibility Conformance")
struct VisibilityConformanceTests {

    /// Build a lightweight section descriptor from a conformance test case.
    /// Only id, component, and visibility are needed for visibility filtering.
    private struct TestSection {
        let id: String
        let visibility: String?
    }

    /// Parse sections from the conformance test case.
    private func parseSections(from dicts: [[String: Any]]) -> [TestSection] {
        dicts.map { dict in
            TestSection(
                id: dict["id"] as! String,
                visibility: dict["visibility"] as? String
            )
        }
    }

    /// Filter sections by evaluating their visibility expressions against the scope.
    /// Sections with nil/empty visibility are always visible.
    private func filterVisible(sections: [TestSection], scope: any ScopeReading) -> [String] {
        sections.compactMap { section in
            let visible = evaluate(expression: section.visibility, scope: scope)
            return visible ? section.id : nil
        }
    }

    @Test("visibility/basic.json")
    func basicVisibility() throws {
        let cases = try ConformanceLoader.loadSuite(category: "visibility", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let sectionDicts = testCase["sections"] as! [[String: Any]]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedVisibleIds = testCase["expectedVisibleIds"] as! [String]

            let sections = parseSections(from: sectionDicts)
            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let visibleIds = filterVisible(sections: sections, scope: scope)

            #expect(
                visibleIds == expectedVisibleIds,
                "FAIL: \(description) — got \(visibleIds), expected \(expectedVisibleIds)"
            )
        }
    }

    @Test("visibility/edge-cases.json")
    func edgeCaseVisibility() throws {
        let cases = try ConformanceLoader.loadSuite(category: "visibility", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let sectionDicts = testCase["sections"] as! [[String: Any]]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedVisibleIds = testCase["expectedVisibleIds"] as! [String]

            let sections = parseSections(from: sectionDicts)
            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let visibleIds = filterVisible(sections: sections, scope: scope)

            #expect(
                visibleIds == expectedVisibleIds,
                "FAIL: \(description) — got \(visibleIds), expected \(expectedVisibleIds)"
            )
        }
    }
}
