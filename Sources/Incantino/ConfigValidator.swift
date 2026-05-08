// ConfigValidator.swift
// Structural and semantic validation for IncantinoConfig.
// Ports validation logic from the Python tooling validator.

import Foundation

// MARK: - ConfigValidator

/// Validates an IncantinoConfig for structural and semantic correctness.
public enum ConfigValidator {

    // MARK: - Report types

    public struct ValidationReport: Sendable {
        public let issues: [ValidationIssue]
        public let screenCount: Int
        public let componentCount: Int

        /// The config passes if there are no error-severity issues.
        public var passed: Bool { !issues.contains { $0.severity == .error } }
    }

    public struct ValidationIssue: Sendable {
        public let severity: Severity
        public let message: String

        public init(severity: Severity, message: String) {
            self.severity = severity
            self.message = message
        }
    }

    public enum Severity: Sendable {
        case error, warning
    }

    // MARK: - Public API

    /// Validate a config, optionally against a vocabulary of known identifiers.
    public static func validate(
        _ config: IncantinoConfig,
        vocabulary: SDUIVocabulary? = nil
    ) -> ValidationReport {
        var issues: [ValidationIssue] = []
        var componentCount = 0

        // 1. Config version.
        validateConfigVersion(config, issues: &issues)

        // 2. Collect screen IDs for cross-reference checks.
        let screenIds = Set(config.screens?.keys ?? Dictionary<String, ScreenSpec>().keys)

        // 3. Validate each screen and count components.
        if let screens = config.screens {
            for (screenId, screen) in screens {
                let count = validateScreen(
                    screen, screenId: screenId,
                    vocabulary: vocabulary, screenIds: screenIds,
                    issues: &issues
                )
                componentCount += count
            }
        }

        // 4. Flow step cross-references.
        validateFlows(config, screenIds: screenIds, issues: &issues)

        // 5. Sheet cross-references.
        validateSheets(config, screenIds: screenIds, issues: &issues)

        // 6. Feature flags referenced in expressions.
        validateFeatureReferences(config, issues: &issues)

        // 7. Theme override hex values.
        validateThemeOverrides(config, issues: &issues)

        return ValidationReport(
            issues: issues,
            screenCount: screenIds.count,
            componentCount: componentCount
        )
    }

    // MARK: - Config version

    private static func validateConfigVersion(
        _ config: IncantinoConfig,
        issues: inout [ValidationIssue]
    ) {
        if let version = config.configVersion, version <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                message: "configVersion must be > 0, got \(version)"
            ))
        }
    }

    // MARK: - Screen validation

    /// Validate a single screen. Returns the number of components found.
    private static func validateScreen(
        _ screen: ScreenSpec,
        screenId: String,
        vocabulary: SDUIVocabulary?,
        screenIds: Set<String>,
        issues: inout [ValidationIssue]
    ) -> Int {
        var componentCount = 0
        for (i, section) in screen.sections.enumerated() {
            componentCount += validateSection(
                section,
                path: "screens.\(screenId).sections[\(i)]",
                vocabulary: vocabulary,
                screenIds: screenIds,
                issues: &issues
            )
        }
        return componentCount
    }

    // MARK: - Section validation (recursive)

    /// Validate a section recursively. Returns the component count in this subtree.
    private static func validateSection(
        _ section: SectionSpec,
        path: String,
        vocabulary: SDUIVocabulary?,
        screenIds: Set<String>,
        issues: inout [ValidationIssue]
    ) -> Int {
        var count = 1

        // Component type check against vocabulary.
        if let vocab = vocabulary {
            if !vocab.componentTypes.contains(section.component) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "\(path): unknown component type '\(section.component)'"
                ))
            }
        }

        // Visibility expression well-formedness.
        if let visibility = section.visibility {
            validateExpression(visibility, path: "\(path).visibility", issues: &issues)
        }

        // Action validation.
        if let action = section.action {
            validateAction(
                action, path: "\(path).action",
                vocabulary: vocabulary, screenIds: screenIds,
                issues: &issues
            )
        }

        // Validation rule expressions.
        if let rules = section.validation {
            for (i, rule) in rules.enumerated() {
                validateExpression(
                    rule.condition,
                    path: "\(path).validation[\(i)].condition",
                    issues: &issues
                )
            }
        }

        // Recurse into children.
        if let children = section.children {
            for (i, child) in children.enumerated() {
                count += validateSection(
                    child,
                    path: "\(path).children[\(i)]",
                    vocabulary: vocabulary,
                    screenIds: screenIds,
                    issues: &issues
                )
            }
        }

        // Recurse into slots.
        if let slots = section.slots {
            for (slotName, slotSections) in slots {
                for (i, slotSection) in slotSections.enumerated() {
                    count += validateSection(
                        slotSection,
                        path: "\(path).slots.\(slotName)[\(i)]",
                        vocabulary: vocabulary,
                        screenIds: screenIds,
                        issues: &issues
                    )
                }
            }
        }

        return count
    }

    // MARK: - Action validation (recursive)

    private static func validateAction(
        _ action: ActionSpec,
        path: String,
        vocabulary: SDUIVocabulary?,
        screenIds: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        // Action type check against vocabulary.
        if let vocab = vocabulary {
            if !vocab.actionTypes.contains(action.action) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "\(path): unknown action type '\(action.action)'"
                ))
            }
        }

        // Navigate target check.
        if action.action == "navigate" {
            if let params = action.params,
               let target = params.string(forKey: "target") {
                if let vocab = vocabulary,
                   !vocab.navigationTargets.contains(target) {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "\(path): navigate target '\(target)' not in vocabulary"
                    ))
                }
            }
        }

        // Guard expression well-formedness.
        if let guardExpr = action.guard {
            validateExpression(guardExpr, path: "\(path).guard", issues: &issues)
        }

        // Recurse into chained actions.
        if let onSuccess = action.onSuccess {
            validateAction(
                onSuccess.value, path: "\(path).onSuccess",
                vocabulary: vocabulary, screenIds: screenIds,
                issues: &issues
            )
        }
        if let onError = action.onError {
            validateAction(
                onError.value, path: "\(path).onError",
                vocabulary: vocabulary, screenIds: screenIds,
                issues: &issues
            )
        }
    }

    // MARK: - Flow validation

    private static func validateFlows(
        _ config: IncantinoConfig,
        screenIds: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        guard let flows = config.flows else { return }

        for (flowId, flow) in flows {
            // Each step must reference an existing screen.
            for (i, stepId) in flow.steps.enumerated() {
                if !screenIds.contains(stepId) {
                    issues.append(ValidationIssue(
                        severity: .error,
                        message: "flows.\(flowId).steps[\(i)]: step '\(stepId)' references nonexistent screen"
                    ))
                }
            }

            // Validate skipIf expressions in stepConfig.
            for (stepId, stepCfg) in flow.stepConfig {
                if let skipIf = stepCfg.skipIf {
                    validateExpression(
                        skipIf,
                        path: "flows.\(flowId).stepConfig.\(stepId).skipIf",
                        issues: &issues
                    )
                }
            }
        }
    }

    // MARK: - Sheet validation

    private static func validateSheets(
        _ config: IncantinoConfig,
        screenIds: Set<String>,
        issues: inout [ValidationIssue]
    ) {
        guard let sheets = config.sheets else { return }

        for (sheetId, screenIdRef) in sheets {
            if !screenIds.contains(screenIdRef) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "sheets.\(sheetId): maps to nonexistent screen '\(screenIdRef)'"
                ))
            }
        }
    }

    // MARK: - Feature flag references

    /// Check that feature flags referenced in visibility/guard expressions
    /// exist in the features dictionary (if features are declared).
    private static func validateFeatureReferences(
        _ config: IncantinoConfig,
        issues: inout [ValidationIssue]
    ) {
        guard let features = config.features else { return }
        let featureKeys = Set(features.keys)

        // Collect all expression strings from the config.
        var expressions: [(String, String)] = []  // (path, expression)
        if let screens = config.screens {
            for (screenId, screen) in screens {
                collectExpressions(
                    from: screen.sections,
                    basePath: "screens.\(screenId)",
                    into: &expressions
                )
            }
        }

        // Check each expression for feature flag paths (features.xxx).
        for (path, expr) in expressions {
            let refs = extractFeatureReferences(expr)
            for ref in refs {
                if !featureKeys.contains(ref) {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "\(path): references feature '\(ref)' not declared in features dict"
                    ))
                }
            }
        }
    }

    /// Recursively collect expression strings from a section tree.
    private static func collectExpressions(
        from sections: [SectionSpec],
        basePath: String,
        into result: inout [(String, String)]
    ) {
        for (i, section) in sections.enumerated() {
            let sectionPath = "\(basePath).sections[\(i)]"

            if let visibility = section.visibility {
                result.append(("\(sectionPath).visibility", visibility))
            }
            if let guardExpr = section.action?.guard {
                result.append(("\(sectionPath).action.guard", guardExpr))
            }
            if let rules = section.validation {
                for (j, rule) in rules.enumerated() {
                    result.append(("\(sectionPath).validation[\(j)]", rule.condition))
                }
            }
            if let children = section.children {
                collectExpressions(
                    from: children,
                    basePath: sectionPath + ".children",
                    into: &result
                )
            }
            if let slots = section.slots {
                for (slotName, slotSections) in slots {
                    collectExpressions(
                        from: slotSections,
                        basePath: "\(sectionPath).slots.\(slotName)",
                        into: &result
                    )
                }
            }
        }
    }

    /// Extract feature flag names from an expression string.
    /// Looks for paths starting with "features." (e.g., "features.darkMode").
    private static func extractFeatureReferences(_ expression: String) -> [String] {
        // Tokenize and look for path tokens starting with "features.".
        guard let tokens = try? Tokenizer.tokenize(expression) else { return [] }
        var refs: [String] = []
        for token in tokens {
            if case .path(let p) = token, p.hasPrefix("features.") {
                let featureName = String(p.dropFirst("features.".count))
                if !featureName.isEmpty {
                    refs.append(featureName)
                }
            }
        }
        return refs
    }

    // MARK: - Theme override hex validation

    private static func validateThemeOverrides(
        _ config: IncantinoConfig,
        issues: inout [ValidationIssue]
    ) {
        guard let overrides = config.themeOverrides else { return }

        let fields: [(String, String?)] = [
            ("background", overrides.background),
            ("surface", overrides.surface),
            ("accent", overrides.accent),
            ("accentSecondary", overrides.accentSecondary),
        ]

        for (name, value) in fields {
            guard let hex = value else { continue }
            if !isValidHexColor(hex) {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "themeOverrides.\(name): invalid hex color '\(hex)' (expected #RGB, #RRGGBB, or #RRGGBBAA)"
                ))
            }
        }
    }

    // MARK: - Expression well-formedness

    /// Check that an expression string parses without error.
    private static func validateExpression(
        _ expr: String,
        path: String,
        issues: inout [ValidationIssue]
    ) {
        do {
            let tokens = try Tokenizer.tokenize(expr)
            var parser = ExpressionParser(tokens: tokens)
            _ = try parser.parse()
        } catch {
            issues.append(ValidationIssue(
                severity: .warning,
                message: "\(path): expression parse error: \(error)"
            ))
        }
    }

    // MARK: - Hex color validation

    /// Validate hex color strings: #RGB, #RRGGBB, or #RRGGBBAA.
    private static func isValidHexColor(_ hex: String) -> Bool {
        guard hex.hasPrefix("#") else { return false }
        let digits = hex.dropFirst()
        let validLengths = [3, 6, 8]  // #RGB, #RRGGBB, #RRGGBBAA
        guard validLengths.contains(digits.count) else { return false }
        return digits.allSatisfy { $0.isHexDigit }
    }
}
