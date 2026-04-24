// ConformanceTestRunner.swift
// Shared infrastructure for loading conformance JSON test suites
// and building scope chains from test case data.

import Foundation
@testable import Incantino

/// Loads conformance test suites from the conformance/ directory.
enum ConformanceLoader {
    /// Find the conformance directory relative to the package root.
    /// #filePath = .../incantino/ios/Tests/IncantinoTests/ConformanceTestRunner.swift
    /// conformance = .../incantino/conformance/
    static func conformanceDirectory() -> URL {
        let thisFile = URL(fileURLWithPath: #filePath)
        let packageRoot = thisFile
            .deletingLastPathComponent()  // IncantinoTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // ios/
        return packageRoot.appendingPathComponent("conformance")
    }

    /// Load a conformance test suite and return its cases array.
    static func loadSuite(category: String, name: String) throws -> [[String: Any]] {
        let url = conformanceDirectory()
            .appendingPathComponent(category)
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        return json["cases"] as! [[String: Any]]
    }

    /// Build a DictionaryScope from a conformance scope dict.
    /// Each key maps to a typed value descriptor: { "type": "text", "value": "..." }.
    static func buildScope(from dict: [String: Any]) -> DictionaryScope {
        let scope = DictionaryScope()
        for (key, value) in dict {
            scope.set(key, value: scopeValue(from: value))
        }
        return scope
    }

    /// Convert a conformance JSON value descriptor to a ScopeValue.
    static func scopeValue(from value: Any) -> ScopeValue {
        guard let dict = value as? [String: Any],
              let type = dict["type"] as? String else {
            return .empty
        }
        switch type {
        case "bool":
            return .bool(dict["value"] as? Bool ?? false)
        case "text":
            return .text(dict["value"] as? String ?? "")
        case "number":
            return .number(dict["value"] as? Double ?? 0)
        case "selection":
            let arr = dict["value"] as? [String] ?? []
            return .selection(Set(arr))
        case "files":
            let arr = dict["value"] as? [String] ?? []
            return .files(arr)
        case "json":
            // Recursively convert the JSON value to a JSONValue enum.
            let jsonVal = jsonValue(from: dict["value"])
            return .json(jsonVal)
        case "empty":
            return .empty
        default:
            return .empty
        }
    }

    /// Convert an arbitrary Foundation JSON object to a JSONValue enum.
    static func jsonValue(from value: Any?) -> JSONValue {
        guard let value = value else { return .null }

        // Bool must be checked before NSNumber/Int/Double since Bool bridges to NSNumber.
        if let b = value as? Bool {
            return .bool(b)
        }
        if let n = value as? NSNumber {
            // Check if the number is integral.
            if n.doubleValue == Double(n.intValue) && !"\(n)".contains(".") {
                return .int(n.intValue)
            }
            return .double(n.doubleValue)
        }
        if let s = value as? String {
            return .string(s)
        }
        if let arr = value as? [Any] {
            return .array(arr.map { jsonValue(from: $0) })
        }
        if let obj = value as? [String: Any] {
            var result: JSONObject = [:]
            for (k, v) in obj {
                result[k] = jsonValue(from: v)
            }
            return .object(result)
        }
        if value is NSNull {
            return .null
        }
        return .null
    }

    /// Compare a ScopeValue against an expected conformance value descriptor.
    /// Returns true if they match.
    static func scopeValueMatches(_ actual: ScopeValue, expected: [String: Any]) -> Bool {
        guard let expectedType = expected["type"] as? String else { return false }

        switch expectedType {
        case "empty":
            if case .empty = actual { return true }
            return false
        case "bool":
            guard let expectedVal = expected["value"] as? Bool else { return false }
            if case .bool(let b) = actual { return b == expectedVal }
            return false
        case "text":
            guard let expectedVal = expected["value"] as? String else { return false }
            if case .text(let s) = actual { return s == expectedVal }
            return false
        case "number":
            guard let expectedVal = expected["value"] as? Double else { return false }
            if case .number(let n) = actual { return n == expectedVal }
            return false
        case "selection":
            guard let expectedVal = expected["value"] as? [String] else { return false }
            if case .selection(let s) = actual { return s == Set(expectedVal) }
            return false
        case "files":
            guard let expectedVal = expected["value"] as? [String] else { return false }
            if case .files(let f) = actual { return f == expectedVal }
            return false
        case "json":
            let expectedJson = jsonValue(from: expected["value"])
            if case .json(let j) = actual { return j == expectedJson }
            return false
        default:
            return false
        }
    }

    /// Format a ScopeValue for debug display in test failure messages.
    static func describeScopeValue(_ value: ScopeValue) -> String {
        switch value {
        case .empty: return ".empty"
        case .bool(let b): return ".bool(\(b))"
        case .text(let s): return ".text(\"\(s)\")"
        case .number(let n): return ".number(\(n))"
        case .selection(let s): return ".selection(\(s))"
        case .files(let f): return ".files(\(f))"
        case .json(let j): return ".json(\(j))"
        }
    }
}
