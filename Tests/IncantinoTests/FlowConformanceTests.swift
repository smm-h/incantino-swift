// FlowConformanceTests.swift
// Conformance tests for multi-step flow sequencing.
// Loads flows/basic.json, flows/edge-cases.json, and flows/branching.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Flow Conformance")
struct FlowConformanceTests {

    /// Build a FlowConfig from a conformance test case's flowConfig dict.
    /// Handles mixed steps arrays containing both strings and sub-flow references.
    private func buildFlowConfig(from dict: [String: Any]) -> FlowConfig {
        let rawSteps = dict["steps"] as? [Any] ?? []
        var steps: [String] = []
        for step in rawSteps {
            if let s = step as? String {
                steps.append(s)
            } else if let obj = step as? [String: Any], let flowId = obj["flow"] as? String {
                // Sub-flow reference: use the flow ID as the step ID.
                steps.append(flowId)
            }
        }

        let stepConfigDict = dict["stepConfig"] as? [String: [String: Any]] ?? [:]

        var stepConfig: [String: FlowStepConfig] = [:]
        for (stepId, cfg) in stepConfigDict {
            let skipIf = cfg["skipIf"] as? String
            let terminal = cfg["terminal"] as? Bool
            let prefill = cfg["prefill"] as? String
            let branchOn = cfg["branchOn"] as? String
            let branches = cfg["branches"] as? [String: String]
            stepConfig[stepId] = FlowStepConfig(
                skipIf: skipIf,
                terminal: terminal,
                prefill: prefill,
                branchOn: branchOn,
                branches: branches
            )
        }

        return FlowConfig(steps: steps, stepConfig: stepConfig)
    }

    @Test("flows/basic.json")
    func basicFlows() throws {
        let cases = try ConformanceLoader.loadSuite(category: "flows", name: "basic")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let flowConfigDict = testCase["flowConfig"] as! [String: Any]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedSequence = testCase["expectedSequence"] as! [String]
            let expectedTerminal = testCase["expectedTerminalStep"] as? String

            let config = buildFlowConfig(from: flowConfigDict)
            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let runner = FlowRunner(flowId: "test", config: config, parentScope: scope)

            // Start the flow (skips initial skippable steps).
            runner.start(scope: scope)

            // Collect the step sequence by advancing through the flow.
            var sequence: [String] = []
            if !runner.isComplete {
                // First step is the current screen after start.
                sequence.append(runner.currentScreenId)
            }

            while !runner.isComplete {
                guard let next = runner.advance(scope: scope) else {
                    break
                }
                sequence.append(next)
            }

            #expect(
                sequence == expectedSequence,
                "FAIL: \(description) — got \(sequence), expected \(expectedSequence)"
            )

            // If there's an expected terminal step, verify the flow stopped there.
            if let terminal = expectedTerminal {
                #expect(
                    runner.currentScreenId == terminal,
                    "FAIL: \(description) — terminal step: got \(runner.currentScreenId), expected \(terminal)"
                )
            }
        }
    }

    @Test("flows/edge-cases.json")
    func edgeCaseFlows() throws {
        let cases = try ConformanceLoader.loadSuite(category: "flows", name: "edge-cases")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let flowConfigDict = testCase["flowConfig"] as! [String: Any]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]
            let expectedSequence = testCase["expectedSequence"] as! [String]
            let expectedTerminal = testCase["expectedTerminalStep"] as? String

            let config = buildFlowConfig(from: flowConfigDict)
            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let runner = FlowRunner(flowId: "test", config: config, parentScope: scope)

            runner.start(scope: scope)

            var sequence: [String] = []
            if !runner.isComplete {
                sequence.append(runner.currentScreenId)
            }

            while !runner.isComplete {
                guard let next = runner.advance(scope: scope) else {
                    break
                }
                sequence.append(next)
            }

            #expect(
                sequence == expectedSequence,
                "FAIL: \(description) — got \(sequence), expected \(expectedSequence)"
            )

            if let terminal = expectedTerminal {
                #expect(
                    runner.currentScreenId == terminal,
                    "FAIL: \(description) — terminal step: got \(runner.currentScreenId), expected \(terminal)"
                )
            }
        }
    }

    @Test("flows/branching.json")
    func branchingFlows() throws {
        let cases = try ConformanceLoader.loadSuite(category: "flows", name: "branching")

        for testCase in cases {
            let description = testCase["description"] as? String ?? "<no description>"
            let flowConfigDict = testCase["flowConfig"] as! [String: Any]
            let scopeDict = testCase["scope"] as? [String: Any] ?? [:]

            // Skip sub-flow tests (they require sub-flow runner orchestration).
            if testCase["subFlows"] != nil {
                continue
            }

            let config = buildFlowConfig(from: flowConfigDict)
            let scope = ConformanceLoader.buildScope(from: scopeDict)
            let runner = FlowRunner(flowId: "test", config: config, parentScope: scope)

            // Operations-based tests: explicit sequence of operations.
            if let operations = testCase["operations"] as? [[String: Any]],
               let expectedResults = testCase["expectedOperationResults"] as? [String] {
                var results: [String] = []

                for op in operations {
                    let opType = op["op"] as! String
                    switch opType {
                    case "start":
                        runner.start(scope: scope)
                        results.append(runner.currentScreenId)
                    case "advance":
                        if let next = runner.advance(scope: scope) {
                            results.append(next)
                        } else {
                            results.append(runner.currentScreenId)
                        }
                    case "retreat":
                        if let prev = runner.retreat() {
                            results.append(prev)
                        } else {
                            results.append(runner.currentScreenId)
                        }
                    case "goTo":
                        let stepId = op["step"] as! String
                        if let target = runner.goTo(stepId: stepId, scope: scope) {
                            results.append(target)
                        } else {
                            results.append(runner.currentScreenId)
                        }
                    case "reset":
                        runner.reset(scope: scope)
                        results.append(runner.currentScreenId)
                    case "scopeWrite":
                        if let values = op["values"] as? [String: Any] {
                            for (key, val) in values {
                                runner.flowScope.set(key, value: ConformanceLoader.scopeValue(from: val))
                            }
                        }
                        results.append(runner.currentScreenId)
                    default:
                        results.append(runner.currentScreenId)
                    }
                }

                #expect(
                    results == expectedResults,
                    "FAIL: \(description) — got \(results), expected \(expectedResults)"
                )
                continue
            }

            // Sequence-based tests: start + advance through.
            if let expectedSequence = testCase["expectedSequence"] as? [String] {
                let expectedTerminal = testCase["expectedTerminalStep"] as? String

                runner.start(scope: scope)

                var sequence: [String] = []
                if !runner.isComplete {
                    sequence.append(runner.currentScreenId)
                }

                while !runner.isComplete {
                    guard let next = runner.advance(scope: scope) else {
                        break
                    }
                    sequence.append(next)
                }

                #expect(
                    sequence == expectedSequence,
                    "FAIL: \(description) — got \(sequence), expected \(expectedSequence)"
                )

                if let terminal = expectedTerminal {
                    #expect(
                        runner.currentScreenId == terminal,
                        "FAIL: \(description) — terminal step: got \(runner.currentScreenId), expected \(terminal)"
                    )
                }

                // Retreat sequence test.
                if let expectedRetreatSequence = testCase["expectedRetreatSequence"] as? [String] {
                    var retreatSeq: [String] = []
                    while let prev = runner.retreat() {
                        retreatSeq.append(prev)
                    }
                    #expect(
                        retreatSeq == expectedRetreatSequence,
                        "FAIL: \(description) retreat — got \(retreatSeq), expected \(expectedRetreatSequence)"
                    )
                }
            }
        }
    }
}
