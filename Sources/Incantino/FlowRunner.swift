// FlowRunner.swift
// Multi-step flow sequencing with skipIf guards, terminal steps, and history.

import Foundation

// MARK: - FlowStepConfig

/// Per-step configuration within a flow.
public struct FlowStepConfig: Codable, Sendable {
    /// Boolean expression; if true when entering the step, skip it.
    public let skipIf: String?
    /// Marks the step as a terminal (no forward navigation).
    public let terminal: Bool?
    /// Data source identifier for pre-filling form values.
    public let prefill: String?
    /// Expression evaluated on advance from this step; its string value selects a branch target.
    public let branchOn: String?
    /// Maps expression result string to target step ID. Used with `branchOn`.
    public let branches: [String: String]?
    /// References another flow by ID. Signals that a sub-flow should be launched.
    public let subFlow: String?

    public init(
        skipIf: String? = nil,
        terminal: Bool? = nil,
        prefill: String? = nil,
        branchOn: String? = nil,
        branches: [String: String]? = nil,
        subFlow: String? = nil
    ) {
        self.skipIf = skipIf
        self.terminal = terminal
        self.prefill = prefill
        self.branchOn = branchOn
        self.branches = branches
        self.subFlow = subFlow
    }
}

// MARK: - FlowConfig

/// Configuration for a flow: ordered steps and per-step config.
public struct FlowConfig: Codable, Sendable {
    /// Ordered array of screen IDs.
    public let steps: [String]
    /// Per-step configuration, keyed by screen ID.
    public let stepConfig: [String: FlowStepConfig]

    public init(steps: [String], stepConfig: [String: FlowStepConfig] = [:]) {
        self.steps = steps
        self.stepConfig = stepConfig
    }
}

// MARK: - FlowRunner

/// Manages step sequencing for multi-screen flows.
/// Thread-safe via NSLock for all mutations.
public final class FlowRunner: @unchecked Sendable {
    private let lock = NSLock()

    /// The flow ID.
    public let flowId: String

    /// The ordered step list.
    private let steps: [String]

    /// Per-step configuration.
    private let stepConfig: [String: FlowStepConfig]

    /// The flow's own scope for accumulating form state.
    public let flowScope: DictionaryScope

    /// Current step index.
    private var currentIndex: Int = 0

    /// Whether the flow has completed.
    private var _isComplete: Bool = false

    /// History stack for back navigation (stores indices of visited steps).
    private var history: [Int] = []

    /// Total number of steps in the flow.
    public var totalSteps: Int { steps.count }

    public init(flowId: String, config: FlowConfig, parentScope: (any ScopeReading)? = nil) {
        self.flowId = flowId
        self.steps = config.steps
        self.stepConfig = config.stepConfig
        self.flowScope = DictionaryScope(parent: parentScope)
    }

    // MARK: - Properties

    /// The screen ID at the current index, or empty string if out of bounds.
    public var currentScreenId: String {
        currentIndex < steps.count ? steps[currentIndex] : ""
    }

    /// Whether the flow has completed.
    public var isComplete: Bool {
        _isComplete
    }

    /// Whether back navigation is available (history stack is non-empty).
    public var canRetreat: Bool {
        !history.isEmpty
    }

    // MARK: - Navigation

    /// Start (or restart) the flow. Skips past initial steps whose skipIf is true.
    /// Alias for `reset(scope:)`.
    public func start(scope: any ScopeReading) {
        reset(scope: scope)
    }

    /// Reset the flow to the beginning and skip forward past skipped steps.
    public func reset(scope: any ScopeReading) {
        lock.lock()
        defer { lock.unlock() }

        history.removeAll()
        _isComplete = false
        currentIndex = 0
        _skipForward(scope: scope)
    }

    /// Advance to the next non-skipped step.
    /// Returns the screen ID of the new step, or nil if the flow is complete.
    @discardableResult
    public func advance(scope: any ScopeReading) -> String? {
        lock.lock()
        defer { lock.unlock() }

        if _isComplete { return nil }

        // Check if current step is terminal.
        let currentStep = currentIndex < steps.count ? steps[currentIndex] : ""
        if let cfg = stepConfig[currentStep], cfg.terminal == true {
            _isComplete = true
            return nil
        }

        // Push current to history.
        history.append(currentIndex)

        // Branch check: if the departing step has branchOn, evaluate and jump.
        if let branchExpr = stepConfig[currentStep]?.branchOn,
           let branchMap = stepConfig[currentStep]?.branches {
            let branchValue = resolveToString(expression: branchExpr, scope: scope)
            if let targetStepId = branchMap[branchValue],
               let targetIndex = steps.firstIndex(of: targetStepId) {
                // Found a branch target. Check skipIf on target, scan forward from there.
                var i = targetIndex
                while i < steps.count {
                    let stepId = steps[i]
                    let cfg = stepConfig[stepId]
                    if let skipIf = cfg?.skipIf, evaluate(expression: skipIf, scope: scope) {
                        i += 1
                        continue
                    }
                    currentIndex = i
                    return steps[i]
                }
                // All steps from branch target onward are skipped.
                _isComplete = true
                return nil
            }
            // No match in branches map: fall through to sequential scan.
        }

        // Scan forward from next index.
        var i = currentIndex + 1
        while i < steps.count {
            let stepId = steps[i]
            let cfg = stepConfig[stepId]
            if let skipIf = cfg?.skipIf, evaluate(expression: skipIf, scope: scope) {
                i += 1
                continue
            }
            // Found a non-skipped step.
            currentIndex = i
            return steps[i]
        }

        // No more steps.
        _isComplete = true
        return nil
    }

    /// Go back one step in the flow history.
    /// Returns the screen ID of the restored step, or nil if no history.
    @discardableResult
    public func retreat() -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard let previousIndex = history.popLast() else {
            return nil
        }

        currentIndex = previousIndex
        _isComplete = false
        return steps[currentIndex]
    }

    /// Jump to a specific step by screen ID, regardless of position.
    /// Does NOT evaluate skipIf on the target. Does NOT check terminal or branchOn.
    /// Returns the target screen ID, or nil if the step is not found or is the current step.
    @discardableResult
    public func goTo(stepId: String, scope: any ScopeReading) -> String? {
        lock.lock()
        defer { lock.unlock() }

        guard let targetIndex = steps.firstIndex(of: stepId) else {
            return nil
        }

        // goTo to current step is a no-op.
        if targetIndex == currentIndex {
            return steps[currentIndex]
        }

        history.append(currentIndex)
        currentIndex = targetIndex
        _isComplete = false
        return steps[currentIndex]
    }

    // MARK: - Active step tracking

    /// Number of non-skipped steps across the entire flow.
    /// Evaluates skipIf for each step at call time.
    public func activeStepCount(scope: any ScopeReading) -> Int {
        var count = 0
        for step in steps {
            let cfg = stepConfig[step]
            if let skipIf = cfg?.skipIf, evaluate(expression: skipIf, scope: scope) {
                continue
            }
            count += 1
        }
        return count
    }

    /// Zero-based index of the current step among non-skipped steps preceding it.
    /// Counts how many non-skipped steps exist before the current index.
    public func activeStepIndex(scope: any ScopeReading) -> Int {
        var index = 0
        for i in 0..<currentIndex {
            let step = steps[i]
            let cfg = stepConfig[step]
            if let skipIf = cfg?.skipIf, evaluate(expression: skipIf, scope: scope) {
                continue
            }
            index += 1
        }
        return index
    }

    // MARK: - Internal

    /// Resolve a branchOn expression to its string value.
    /// Uses the expression tokenizer/parser to resolve a path against the scope,
    /// then coerces to a string. Returns empty string if unresolvable.
    private func resolveToString(expression: String, scope: any ScopeReading) -> String {
        let value = scope.resolve(expression)
        return value.stringValue ?? ""
    }

    /// Skip forward past steps whose skipIf evaluates to true.
    /// Must be called under lock.
    private func _skipForward(scope: any ScopeReading) {
        while currentIndex < steps.count {
            let stepId = steps[currentIndex]
            let cfg = stepConfig[stepId]
            if let skipIf = cfg?.skipIf, evaluate(expression: skipIf, scope: scope) {
                currentIndex += 1
                continue
            }
            return
        }
        // All steps skipped.
        _isComplete = true
    }
}
