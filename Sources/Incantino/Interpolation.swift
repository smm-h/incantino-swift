// Interpolation.swift
// Text interpolation engine for {{path}} patterns.

import Foundation

/// Resolves `{{path}}` patterns in template strings against a scope.
public enum TextInterpolator {
    // Regex matching {{...}} tokens (non-greedy).
    private static let pattern = try! NSRegularExpression(pattern: "\\{\\{(.*?)\\}\\}")

    /// Resolve all `{{path}}` tokens in the template against the given scope.
    ///
    /// - Fast path: returns unchanged if no `{{` present.
    /// - Empty braces `{{}}` are left verbatim.
    /// - Unresolved paths (`.empty`) are left verbatim.
    /// - Numbers are formatted cleanly (whole numbers drop `.0`).
    public static func resolve(_ template: String, scope: any ScopeReading) -> String {
        // Fast path: skip regex if no {{ present.
        guard template.contains("{{") else {
            return template
        }

        let nsTemplate = template as NSString
        let fullRange = NSRange(location: 0, length: nsTemplate.length)
        let matches = pattern.matches(in: template, range: fullRange)

        // No matches found (edge case: {{ without }}).
        guard !matches.isEmpty else { return template }

        // Process in reverse order so replacement ranges stay valid.
        var result = nsTemplate as String
        for match in matches.reversed() {
            let fullMatchRange = match.range
            let innerRange = match.range(at: 1)
            let rawPath = nsTemplate.substring(with: innerRange)
            let trimmed = rawPath.trimmingCharacters(in: .whitespaces)

            // Empty braces: leave as-is.
            if trimmed.isEmpty {
                continue
            }

            let value = scope.resolve(trimmed)

            // Unresolved: leave original token verbatim.
            if case .empty = value {
                continue
            }

            // Format the resolved value for display.
            let replacement: String
            switch value {
            case .number(let n):
                replacement = formatNumber(n)
            default:
                replacement = value.stringValue ?? ""
            }

            // Replace using the Swift String range.
            let startIdx = result.index(result.startIndex, offsetBy: fullMatchRange.location)
            let endIdx = result.index(startIdx, offsetBy: fullMatchRange.length)
            result.replaceSubrange(startIdx..<endIdx, with: replacement)
        }

        return result
    }
}
