// FlowConformanceTests.swift
// Conformance tests for multi-step flow sequencing.
// Loads flows/basic.json and flows/edge-cases.json.

import Testing
import Foundation
@testable import Incantino

@Suite("Flow Conformance")
struct FlowConformanceTests {

    /// Build a FlowConfig from a conformance test case's flowConfig dict.
    private func buildFlowConfig(from dict: [String: Any]) -> FlowConfig {
        let steps = dict["steps"] as? [String] ?? []
        let stepConfigDict = dict["stepConfig"] as? [String: [String: Any]] ?? [:]

        var stepConfig: [String: FlowStepConfig] = [:]
        for (stepId, cfg) in stepConfigDict {
            let skipIf = cfg["skipIf"] as? String
            let terminal = cfg["terminal"] as? Bool
            let prefill = cfg["prefill"] as? String
            stepConfig[stepId] = FlowStepConfig(skipIf: skipIf, terminal: terminal, prefill: prefill)
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
}
